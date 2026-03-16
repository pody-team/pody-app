package config

import (
	"strings"
	"testing"
)

func TestLoadRequiresSMTPSettingsInSMTPMode(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5433/pody_notification?sslmode=disable")
	t.Setenv("INTERNAL_API_KEY", "change-me")
	t.Setenv("KAFKA_BROKERS", "localhost:9092")
	t.Setenv("EMAIL_SENDER_MODE", "smtp")
	t.Setenv("EMAIL_FROM", "sender@example.com")
	t.Setenv("SMTP_HOST", "smtp.example.com")
	t.Setenv("SMTP_PORT", "587")
	t.Setenv("SMTP_USERNAME", "")
	t.Setenv("SMTP_PASSWORD", "secret")

	_, err := Load()
	if err == nil || !strings.Contains(err.Error(), "SMTP_USERNAME") {
		t.Fatalf("expected SMTP_USERNAME validation error, got %v", err)
	}
}

func TestLoadParsesSMTPSettings(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5433/pody_notification?sslmode=disable")
	t.Setenv("INTERNAL_API_KEY", "change-me")
	t.Setenv("KAFKA_BROKERS", "localhost:9092")
	t.Setenv("EMAIL_SENDER_MODE", "smtp")
	t.Setenv("EMAIL_FROM", "sender@example.com")
	t.Setenv("SMTP_HOST", "smtp.example.com")
	t.Setenv("SMTP_PORT", "465")
	t.Setenv("SMTP_USERNAME", "sender@example.com")
	t.Setenv("SMTP_PASSWORD", "secret")
	t.Setenv("SMTP_TLS_MODE", "tls")
	t.Setenv("SMTP_INSECURE_SKIP_VERIFY", "true")
	t.Setenv("SMTP_DIAL_TIMEOUT", "15s")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}

	if cfg.SMTPTLSMode != "tls" {
		t.Fatalf("expected tls mode tls, got %q", cfg.SMTPTLSMode)
	}
	if !cfg.SMTPInsecureSkipVerify {
		t.Fatal("expected SMTPInsecureSkipVerify to be true")
	}
	if cfg.SMTPDialTimeout.String() != "15s" {
		t.Fatalf("expected SMTP dial timeout 15s, got %s", cfg.SMTPDialTimeout)
	}
}
