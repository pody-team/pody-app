package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port                            string
	DatabaseURL                     string
	ShutdownTimeout                 time.Duration
	InternalAPIKey                  string
	EmailSenderMode                 string
	EmailFrom                       string
	SMTPHost                        string
	SMTPPort                        string
	SMTPUsername                    string
	SMTPPassword                    string
	SMTPTLSMode                     string
	SMTPInsecureSkipVerify          bool
	SMTPDialTimeout                 time.Duration
	KafkaBrokers                    []string
	KafkaClientID                   string
	KafkaWriteTimeout               time.Duration
	VerificationTopic               string
	VerificationRetryTopic          string
	VerificationDLQTopic            string
	VerificationConsumerGroup       string
	VerificationMaxAttempts         int
	PasswordResetTopic              string
	PasswordResetRetryTopic         string
	PasswordResetDLQTopic           string
	PasswordResetConsumerGroup      string
	PasswordResetMaxAttempts        int
	ProcessedEventsRetention        time.Duration
	ProcessedEventsCleanupInterval  time.Duration
	ProcessedEventsCleanupBatchSize int
}

func Load() (Config, error) {
	kafkaWriteTimeout, err := durationFromEnv("KAFKA_WRITE_TIMEOUT", 5*time.Second)
	if err != nil {
		return Config{}, err
	}

	processedEventsRetention, err := durationFromEnv("PROCESSED_EVENTS_RETENTION", 7*24*time.Hour)
	if err != nil {
		return Config{}, err
	}

	processedEventsCleanupInterval, err := durationFromEnv("PROCESSED_EVENTS_CLEANUP_INTERVAL", time.Hour)
	if err != nil {
		return Config{}, err
	}

	shutdownTimeout, err := durationFromEnv("SHUTDOWN_TIMEOUT", 10*time.Second)
	if err != nil {
		return Config{}, err
	}

	smtpDialTimeout, err := durationFromEnv("SMTP_DIAL_TIMEOUT", 10*time.Second)
	if err != nil {
		return Config{}, err
	}

	cfg := Config{
		DatabaseURL:                     stringFromEnv("DATABASE_URL", ""),
		Port:                            stringFromEnv("PORT", "8087"),
		ShutdownTimeout:                 shutdownTimeout,
		InternalAPIKey:                  stringFromEnv("INTERNAL_API_KEY", "change-me"),
		EmailSenderMode:                 stringFromEnv("EMAIL_SENDER_MODE", "log"),
		EmailFrom:                       stringFromEnv("EMAIL_FROM", "no-reply@pody.local"),
		SMTPHost:                        stringFromEnv("SMTP_HOST", ""),
		SMTPPort:                        stringFromEnv("SMTP_PORT", "587"),
		SMTPUsername:                    stringFromEnv("SMTP_USERNAME", ""),
		SMTPPassword:                    stringFromEnv("SMTP_PASSWORD", ""),
		SMTPTLSMode:                     stringFromEnv("SMTP_TLS_MODE", "starttls"),
		SMTPInsecureSkipVerify:          boolFromEnv("SMTP_INSECURE_SKIP_VERIFY", false),
		SMTPDialTimeout:                 smtpDialTimeout,
		KafkaBrokers:                    csvFromEnv("KAFKA_BROKERS", []string{"localhost:9092"}),
		KafkaClientID:                   stringFromEnv("KAFKA_CLIENT_ID", "notification-service"),
		KafkaWriteTimeout:               kafkaWriteTimeout,
		VerificationTopic:               stringFromEnv("VERIFICATION_EVENTS_TOPIC", "identity.email.verification.requested"),
		VerificationRetryTopic:          stringFromEnv("VERIFICATION_RETRY_TOPIC", "identity.email.verification.requested.retry"),
		VerificationDLQTopic:            stringFromEnv("VERIFICATION_DLQ_TOPIC", "identity.email.verification.requested.dlq"),
		VerificationConsumerGroup:       stringFromEnv("VERIFICATION_CONSUMER_GROUP", "notification-service"),
		VerificationMaxAttempts:         intFromEnv("VERIFICATION_MAX_ATTEMPTS", 5),
		PasswordResetTopic:              stringFromEnv("PASSWORD_RESET_EVENTS_TOPIC", "identity.password.reset.requested"),
		PasswordResetRetryTopic:         stringFromEnv("PASSWORD_RESET_RETRY_TOPIC", "identity.password.reset.requested.retry"),
		PasswordResetDLQTopic:           stringFromEnv("PASSWORD_RESET_DLQ_TOPIC", "identity.password.reset.requested.dlq"),
		PasswordResetConsumerGroup:      stringFromEnv("PASSWORD_RESET_CONSUMER_GROUP", "notification-service-password-reset"),
		PasswordResetMaxAttempts:        intFromEnv("PASSWORD_RESET_MAX_ATTEMPTS", 5),
		ProcessedEventsRetention:        processedEventsRetention,
		ProcessedEventsCleanupInterval:  processedEventsCleanupInterval,
		ProcessedEventsCleanupBatchSize: intFromEnv("PROCESSED_EVENTS_CLEANUP_BATCH_SIZE", 500),
	}

	if strings.TrimSpace(cfg.DatabaseURL) == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}

	if strings.TrimSpace(cfg.InternalAPIKey) == "" {
		return Config{}, fmt.Errorf("INTERNAL_API_KEY is required")
	}

	if len(cfg.KafkaBrokers) == 0 {
		return Config{}, fmt.Errorf("KAFKA_BROKERS is required")
	}

	if strings.EqualFold(strings.TrimSpace(cfg.EmailSenderMode), "smtp") {
		if strings.TrimSpace(cfg.EmailFrom) == "" {
			return Config{}, fmt.Errorf("EMAIL_FROM is required when EMAIL_SENDER_MODE=smtp")
		}
		if strings.TrimSpace(cfg.SMTPHost) == "" {
			return Config{}, fmt.Errorf("SMTP_HOST is required when EMAIL_SENDER_MODE=smtp")
		}
		if strings.TrimSpace(cfg.SMTPPort) == "" {
			return Config{}, fmt.Errorf("SMTP_PORT is required when EMAIL_SENDER_MODE=smtp")
		}
		if strings.TrimSpace(cfg.SMTPUsername) == "" {
			return Config{}, fmt.Errorf("SMTP_USERNAME is required when EMAIL_SENDER_MODE=smtp")
		}
		if strings.TrimSpace(cfg.SMTPPassword) == "" {
			return Config{}, fmt.Errorf("SMTP_PASSWORD is required when EMAIL_SENDER_MODE=smtp")
		}
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
	items := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			items = append(items, part)
		}
	}

	if len(items) == 0 {
		return fallback
	}

	return items
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

	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 {
		return fallback
	}

	return parsed
}

func boolFromEnv(key string, fallback bool) bool {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}

	return parsed
}
