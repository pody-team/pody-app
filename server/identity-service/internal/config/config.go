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
	OutboxBatchSize        int
	OutboxCleanupBatchSize int
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
		DatabaseURL:            stringFromEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/pody_identity?sslmode=disable"),
		JWTSecret:              stringFromEnv("JWT_SECRET", "change-me"),
		AccessTokenTTL:         accessTokenTTL,
		RefreshTokenTTL:        refreshTokenTTL,
		VerificationTTL:        verificationTTL,
		KafkaWriteTimeout:      kafkaWriteTimeout,
		OutboxPollInterval:     outboxPollInterval,
		OutboxRetention:        outboxRetention,
		OutboxCleanupInterval:  outboxCleanupInterval,
		ShutdownTimeout:        shutdownTimeout,
		GoogleClientIDs:        csvFromEnv("GOOGLE_CLIENT_IDS", nil),
		KafkaBrokers:           csvFromEnv("KAFKA_BROKERS", []string{"localhost:9092"}),
		KafkaClientID:          stringFromEnv("KAFKA_CLIENT_ID", "identity-service"),
		VerificationTopic:      stringFromEnv("VERIFICATION_EVENTS_TOPIC", "identity.email.verification.requested"),
		VerificationURLBase:    stringFromEnv("EMAIL_VERIFICATION_URL_BASE", "http://localhost:8080/api/v1/public/identity/verify-email"),
		OutboxBatchSize:        intFromEnv("OUTBOX_BATCH_SIZE", 20),
		OutboxCleanupBatchSize: intFromEnv("OUTBOX_CLEANUP_BATCH_SIZE", 200),
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
