package main

import (
	"context"
	"database/sql"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/promex04/pody/server/identity-service/internal/auth"
	"github.com/promex04/pody/server/identity-service/internal/config"
	"github.com/promex04/pody/server/identity-service/internal/googleauth"
	"github.com/promex04/pody/server/identity-service/internal/httpserver"
	"github.com/promex04/pody/server/identity-service/internal/media"
	"github.com/promex04/pody/server/identity-service/internal/notification"
	"github.com/promex04/pody/server/identity-service/internal/outbox"
	"github.com/promex04/pody/server/identity-service/internal/store"
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	cfg, err := config.Load()
	if err != nil {
		logger.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	db, err := sql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		logger.Error("failed to open database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		logger.Error("failed to ping database", "error", err)
		os.Exit(1)
	}

	repo := store.NewPostgresRepository(db)
	tokenManager := auth.NewTokenManager(cfg.JWTSecret, cfg.AccessTokenTTL, cfg.RefreshTokenTTL)
	googleVerifier := googleauth.NewVerifier(cfg.GoogleClientIDs)
	notificationProducer, err := notification.NewProducer(cfg.KafkaBrokers, cfg.VerificationTopic, cfg.KafkaClientID, cfg.KafkaWriteTimeout)
	if err != nil {
		logger.Error("failed to create notification producer", "error", err)
		os.Exit(1)
	}
	defer notificationProducer.Close()

	authService := auth.NewService(
		repo,
		tokenManager,
		googleVerifier,
		cfg.VerificationTTL,
		cfg.VerificationURLBase,
		cfg.VerificationTopic,
		cfg.PasswordResetTTL,
		cfg.PasswordResetTopic,
	)
	outboxPublisher := outbox.NewPublisher(repo, notificationProducer, logger, cfg.OutboxPollInterval, cfg.OutboxBatchSize)
	outboxCleanup := outbox.NewCleanupWorker(repo, logger, cfg.OutboxCleanupInterval, cfg.OutboxRetention, cfg.OutboxCleanupBatchSize)
	var avatarStorage media.AvatarStorage
	if cfg.MinIOEndpoint != "" {
		storage, err := media.NewMinIOAvatarStorage(media.Config{
			Endpoint:       cfg.MinIOEndpoint,
			AccessKey:      cfg.MinIOAccessKey,
			SecretKey:      cfg.MinIOSecretKey,
			UseSSL:         cfg.MinIOUseSSL,
			BucketName:     cfg.MinIOBucketName,
			PublicBaseURL:  cfg.MinIOPublicBaseURL,
			Region:         cfg.MinIORegion,
			MaxAvatarBytes: cfg.MaxAvatarBytes,
		})
		if err != nil {
			logger.Error("failed to create avatar storage", "error", err)
			os.Exit(1)
		}
		if err := ensureAvatarBucket(context.Background(), storage, logger, cfg.MinIOBucketName); err != nil {
			logger.Error("failed to ensure minio avatar bucket", "bucket", cfg.MinIOBucketName, "error", err)
			os.Exit(1)
		}
		avatarStorage = storage
		logger.Info("avatar storage ready", "bucket", cfg.MinIOBucketName, "public_base_url", cfg.MinIOPublicBaseURL)
	}

	server := httpserver.New(cfg, logger, authService, avatarStorage)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 3)
	go func() {
		logger.Info("starting identity service", "addr", server.Addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errCh <- err
			return
		}
		errCh <- nil
	}()

	go func() {
		logger.Info("starting outbox publisher", "topic", cfg.VerificationTopic)
		errCh <- outboxPublisher.Run(ctx)
	}()

	go func() {
		logger.Info("starting outbox cleanup", "retention", cfg.OutboxRetention.String())
		errCh <- outboxCleanup.Run(ctx)
	}()

	select {
	case err := <-errCh:
		if err != nil && !errors.Is(err, context.Canceled) {
			logger.Error("identity service stopped", "error", err)
			stop()
			os.Exit(1)
		}
	case <-ctx.Done():
		logger.Info("shutdown signal received")
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown failed", "error", err)
		os.Exit(1)
	}
}

func ensureAvatarBucket(ctx context.Context, storage media.AvatarStorage, logger *slog.Logger, bucketName string) error {
	var lastErr error
	for attempt := 1; attempt <= 15; attempt++ {
		if err := storage.EnsureBucket(ctx); err == nil {
			return nil
		} else {
			lastErr = err
			logger.Warn("avatar bucket is not ready yet", "bucket", bucketName, "attempt", attempt, "error", err)
		}
		time.Sleep(2 * time.Second)
	}
	return lastErr
}
