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

// main là điểm khởi chạy chính của Identity Service.
// Đảm nhận: khởi tạo kết nối Database (Postgres), Kafka Producer, lưu trữ Object Storage (MinIO),
// chạy HTTP Server và các worker chạy ngầm của Outbox Pattern.
func main() {
	// Khởi tạo logger ghi log ra Stdout dưới dạng text
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	// Tải cấu hình từ các biến môi trường
	cfg, err := config.Load()
	if err != nil {
		logger.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	// Kết nối tới cơ sở dữ liệu PostgreSQL sử dụng pgx driver
	db, err := sql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		logger.Error("failed to open database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	// Ping thử tới Database để kiểm tra kết nối có thông suốt không
	if err := db.Ping(); err != nil {
		logger.Error("failed to ping database", "error", err)
		os.Exit(1)
	}

	// Khởi tạo Repository làm việc với Postgres
	repo := store.NewPostgresRepository(db)
	// Khởi tạo TokenManager hỗ trợ sinh và verify JWT tokens (Access token, Refresh token)
	tokenManager := auth.NewTokenManager(cfg.JWTSecret, cfg.AccessTokenTTL, cfg.RefreshTokenTTL)
	// Khởi tạo đối tượng xác thực OAuth Google
	googleVerifier := googleauth.NewVerifier(cfg.GoogleClientIDs)
	// Khởi tạo Kafka Producer để gửi thông báo (email verification, password reset, etc.)
	notificationProducer, err := notification.NewProducer(cfg.KafkaBrokers, cfg.VerificationTopic, cfg.KafkaClientID, cfg.KafkaWriteTimeout)
	if err != nil {
		logger.Error("failed to create notification producer", "error", err)
		os.Exit(1)
	}
	defer notificationProducer.Close()

	// Khởi tạo Authentication Service chính của hệ thống chứa nghiệp vụ Auth
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
	
	// Khởi tạo Outbox Publisher để định kỳ quét bảng outbox_events và đẩy sự kiện lên Kafka
	outboxPublisher := outbox.NewPublisher(repo, notificationProducer, logger, cfg.OutboxPollInterval, cfg.OutboxBatchSize)
	// Khởi tạo Outbox Cleanup Worker định kỳ dọn dẹp các outbox event cũ đã được gửi đi thành công
	outboxCleanup := outbox.NewCleanupWorker(repo, logger, cfg.OutboxCleanupInterval, cfg.OutboxRetention, cfg.OutboxCleanupBatchSize)
	
	// Cấu hình lưu trữ ảnh đại diện người dùng (Avatar) sử dụng MinIO
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
		// Đảm bảo bucket lưu ảnh avatar đã tồn tại (retry nếu cần)
		if err := ensureAvatarBucket(context.Background(), storage, logger, cfg.MinIOBucketName); err != nil {
			logger.Error("failed to ensure minio avatar bucket", "bucket", cfg.MinIOBucketName, "error", err)
			os.Exit(1)
		}
		avatarStorage = storage
		logger.Info("avatar storage ready", "bucket", cfg.MinIOBucketName, "public_base_url", cfg.MinIOPublicBaseURL)
	}

	// Khởi tạo HTTP Server cho Identity Service
	server := httpserver.New(cfg, logger, authService, avatarStorage)

	// Lắng nghe tín hiệu dừng hệ thống (SIGINT, SIGTERM) để tắt graceful
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 3)
	
	// 1. Chạy HTTP Server trong 1 goroutine
	go func() {
		logger.Info("starting identity service", "addr", server.Addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errCh <- err
			return
		}
		errCh <- nil
	}()

	// 2. Chạy Outbox Publisher trong 1 goroutine
	go func() {
		logger.Info("starting outbox publisher", "topic", cfg.VerificationTopic)
		errCh <- outboxPublisher.Run(ctx)
	}()

	// 3. Chạy Outbox Cleanup Worker trong 1 goroutine
	go func() {
		logger.Info("starting outbox cleanup", "retention", cfg.OutboxRetention.String())
		errCh <- outboxCleanup.Run(ctx)
	}()

	// Chờ tín hiệu ngắt hoặc lỗi xảy ra trong các goroutine chạy nền
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

	// Thực hiện tắt graceful HTTP server
	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown failed", "error", err)
		os.Exit(1)
	}
}

// ensureAvatarBucket cố gắng kiểm tra và tạo bucket trên MinIO, thực hiện retry lên tới 15 lần (mỗi lần cách nhau 2 giây).
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

