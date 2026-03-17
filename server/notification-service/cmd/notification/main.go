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

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/promex04/pody/server/notification-service/internal/cleanup"
	"github.com/promex04/pody/server/notification-service/internal/config"
	"github.com/promex04/pody/server/notification-service/internal/consumer"
	"github.com/promex04/pody/server/notification-service/internal/email"
	"github.com/promex04/pody/server/notification-service/internal/httpserver"
	"github.com/promex04/pody/server/notification-service/internal/store"
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

	sender := email.NewSender(email.Config{
		Mode:         cfg.EmailSenderMode,
		EmailFrom:    cfg.EmailFrom,
		SMTPHost:     cfg.SMTPHost,
		SMTPPort:     cfg.SMTPPort,
		SMTPUsername: cfg.SMTPUsername,
		SMTPPassword: cfg.SMTPPassword,
		TLSMode:      cfg.SMTPTLSMode,
		DialTimeout:  cfg.SMTPDialTimeout,
		SkipVerify:   cfg.SMTPInsecureSkipVerify,
	}, logger)

	processedStore := store.NewPostgresStore(db)
	server := httpserver.New(cfg, logger, sender, processedStore)
	verificationConsumer, err := consumer.NewVerificationConsumer(cfg, logger, sender, processedStore, processedStore)
	if err != nil {
		logger.Error("failed to create verification consumer", "error", err)
		os.Exit(1)
	}
	passwordResetConsumer, err := consumer.NewPasswordResetConsumer(cfg, logger, sender, processedStore, processedStore)
	if err != nil {
		logger.Error("failed to create password reset consumer", "error", err)
		os.Exit(1)
	}
	processedEventsCleanup := cleanup.NewProcessedEventsWorker(processedStore, logger, cfg.ProcessedEventsCleanupInterval, cfg.ProcessedEventsRetention, cfg.ProcessedEventsCleanupBatchSize)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 4)
	go func() {
		logger.Info("starting notification service", "addr", server.Addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errCh <- err
			return
		}
		errCh <- nil
	}()

	go func() {
		logger.Info("starting verification consumer", "brokers", cfg.KafkaBrokers, "topic", cfg.VerificationTopic)
		errCh <- verificationConsumer.Run(ctx)
	}()

	go func() {
		logger.Info("starting password reset consumer", "brokers", cfg.KafkaBrokers, "topic", cfg.PasswordResetTopic)
		errCh <- passwordResetConsumer.Run(ctx)
	}()

	go func() {
		logger.Info("starting processed events cleanup", "retention", cfg.ProcessedEventsRetention.String())
		errCh <- processedEventsCleanup.Run(ctx)
	}()

	select {
	case err := <-errCh:
		if err != nil && !errors.Is(err, context.Canceled) {
			logger.Error("notification service stopped", "error", err)
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
