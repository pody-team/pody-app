package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port                   string
	DatabaseURL            string
	JWTSecret              string
	AccessTokenTTL         time.Duration
	RefreshTokenTTL        time.Duration
	VerificationTTL        time.Duration
	PasswordResetTTL       time.Duration
	KafkaWriteTimeout      time.Duration
	OutboxPollInterval     time.Duration
	OutboxRetention        time.Duration
	OutboxCleanupInterval  time.Duration
	ShutdownTimeout        time.Duration
	GoogleClientIDs        []string
	KafkaBrokers           []string
	KafkaClientID          string
	VerificationTopic      string
	VerificationURLBase    string
	PasswordResetTopic     string
	OutboxBatchSize        int
	OutboxCleanupBatchSize int
	MinIOEndpoint          string
	MinIOAccessKey         string
	MinIOSecretKey         string
	MinIOBucketName        string
	MinIORegion            string
	MinIOPublicBaseURL     string
	MinIOUseSSL            bool
	MaxAvatarBytes         int64
}

func Load() (Config, error) {
	accessTokenTTL, err := durationFromEnv("ACCESS_TOKEN_TTL", 15*time.Minute)
	if err != nil {
		return Config{}, err
	}

	refreshTokenTTL, err := durationFromEnv("REFRESH_TOKEN_TTL", 30*24*time.Hour)
	if err != nil {
		return Config{}, err
	}

	verificationTTL, err := durationFromEnv("EMAIL_VERIFICATION_TTL", 24*time.Hour)
	if err != nil {
		return Config{}, err
	}

	passwordResetTTL, err := durationFromEnv("PASSWORD_RESET_TTL", 2*time.Hour)
	if err != nil {
		return Config{}, err
	}

	kafkaWriteTimeout, err := durationFromEnv("KAFKA_WRITE_TIMEOUT", 5*time.Second)
	if err != nil {
		return Config{}, err
	}

	outboxPollInterval, err := durationFromEnv("OUTBOX_POLL_INTERVAL", time.Second)
	if err != nil {
		return Config{}, err
	}

	outboxRetention, err := durationFromEnv("OUTBOX_RETENTION", 7*24*time.Hour)
	if err != nil {
		return Config{}, err
	}

	outboxCleanupInterval, err := durationFromEnv("OUTBOX_CLEANUP_INTERVAL", time.Hour)
	if err != nil {
		return Config{}, err
	}

	shutdownTimeout, err := durationFromEnv("SHUTDOWN_TIMEOUT", 10*time.Second)
	if err != nil {
		return Config{}, err
	}

	cfg := Config{
		Port:                   stringFromEnv("PORT", "8081"),
		DatabaseURL:            stringFromEnv("DATABASE_URL", ""),
		JWTSecret:              stringFromEnv("JWT_SECRET", "change-me"),
		AccessTokenTTL:         accessTokenTTL,
		RefreshTokenTTL:        refreshTokenTTL,
		VerificationTTL:        verificationTTL,
		PasswordResetTTL:       passwordResetTTL,
		KafkaWriteTimeout:      kafkaWriteTimeout,
		OutboxPollInterval:     outboxPollInterval,
		OutboxRetention:        outboxRetention,
		OutboxCleanupInterval:  outboxCleanupInterval,
		ShutdownTimeout:        shutdownTimeout,
		GoogleClientIDs:        csvFromEnv("GOOGLE_CLIENT_IDS", nil),
		KafkaBrokers:           csvFromEnv("KAFKA_BROKERS", []string{"localhost:9092"}),
		KafkaClientID:          stringFromEnv("KAFKA_CLIENT_ID", "identity-service"),
		VerificationTopic:      stringFromEnv("VERIFICATION_EVENTS_TOPIC", "identity.email.verification.requested"),
		VerificationURLBase:    stringFromEnv("EMAIL_VERIFICATION_URL_BASE", "http://localhost:8080/verify-email/open"),
		PasswordResetTopic:     stringFromEnv("PASSWORD_RESET_EVENTS_TOPIC", "identity.password.reset.requested"),
		OutboxBatchSize:        intFromEnv("OUTBOX_BATCH_SIZE", 20),
		OutboxCleanupBatchSize: intFromEnv("OUTBOX_CLEANUP_BATCH_SIZE", 200),
		MinIOEndpoint:          stringFromEnv("MINIO_ENDPOINT", ""),
		MinIOAccessKey:         stringFromEnv("MINIO_ROOT_USER", ""),
		MinIOSecretKey:         stringFromEnv("MINIO_ROOT_PASSWORD", ""),
		MinIOBucketName:        stringFromEnv("MINIO_AVATAR_BUCKET", "identity-avatars"),
		MinIORegion:            stringFromEnv("MINIO_REGION", "us-east-1"),
		MinIOPublicBaseURL:     stringFromEnv("MINIO_PUBLIC_BASE_URL", ""),
		MinIOUseSSL:            boolFromEnv("MINIO_USE_SSL", false),
		MaxAvatarBytes:         int64FromEnv("IDENTITY_MAX_AVATAR_BYTES", 5<<20),
	}

	if strings.TrimSpace(cfg.DatabaseURL) == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}

	if strings.TrimSpace(cfg.JWTSecret) == "" {
		return Config{}, fmt.Errorf("JWT_SECRET is required")
	}

	if len(cfg.KafkaBrokers) == 0 {
		return Config{}, fmt.Errorf("KAFKA_BROKERS is required")
	}

	return cfg, nil
}

func (c Config) Addr() string {
	return ":" + c.Port
}

func stringFromEnv(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	return value
}

func csvFromEnv(key string, fallback []string) []string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			result = append(result, part)
		}
	}

	if len(result) == 0 {
		return fallback
	}

	return result
}

func durationFromEnv(key string, fallback time.Duration) (time.Duration, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback, nil
	}

	duration, err := time.ParseDuration(value)
	if err != nil {
		return 0, fmt.Errorf("invalid %s: %w", key, err)
	}

	return duration, nil
}

func intFromEnv(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	result, err := strconv.Atoi(value)
	if err != nil || result <= 0 {
		return fallback
	}

	return result
}

func int64FromEnv(key string, fallback int64) int64 {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	result, err := strconv.ParseInt(value, 10, 64)
	if err != nil || result <= 0 {
		return fallback
	}

	return result
}

func boolFromEnv(key string, fallback bool) bool {
	value := strings.TrimSpace(strings.ToLower(os.Getenv(key)))
	if value == "" {
		return fallback
	}

	switch value {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return fallback
	}
}
