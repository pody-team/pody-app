package email

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/smtp"
	"strings"
	"time"
)

type VerificationMessage struct {
	EventID         string    `json:"event_id,omitempty"`
	IdempotencyKey  string    `json:"idempotency_key,omitempty"`
	ToEmail         string    `json:"to_email"`
	ToDisplayName   string    `json:"to_display_name"`
	VerificationURL string    `json:"verification_url"`
	ExpiresAt       time.Time `json:"expires_at"`
}

type Sender interface {
	SendVerification(ctx context.Context, message VerificationMessage) error
}

type Config struct {
	Mode         string
	EmailFrom    string
	SMTPHost     string
	SMTPPort     string
	SMTPUsername string
	SMTPPassword string
	TLSMode      string
	DialTimeout  time.Duration
	SkipVerify   bool
}

func NewSender(cfg Config, logger *slog.Logger) Sender {
	if strings.EqualFold(strings.TrimSpace(cfg.Mode), "smtp") && strings.TrimSpace(cfg.SMTPHost) != "" {
		return smtpSender{cfg: cfg}
	}

	return logSender{logger: logger}
}

type logSender struct {
	logger *slog.Logger
}

func (s logSender) SendVerification(_ context.Context, message VerificationMessage) error {
	s.logger.Info("verification email dispatched",
		"email", message.ToEmail,
		"verification_url", message.VerificationURL,
		"expires_at", message.ExpiresAt.Format(time.RFC3339),
	)
	return nil
}

type smtpSender struct {
	cfg Config
}

func (s smtpSender) SendVerification(_ context.Context, message VerificationMessage) error {
	addr := s.cfg.SMTPHost + ":" + s.cfg.SMTPPort
	body := fmt.Sprintf(
		"Hello %s,\n\nPlease verify your Pody account by opening this link:\n%s\n\nThis link expires at %s.\n",
		fallbackName(message.ToDisplayName, message.ToEmail),
		message.VerificationURL,
		message.ExpiresAt.Format(time.RFC1123Z),
	)

	raw := strings.Join([]string{
		"From: " + s.cfg.EmailFrom,
		"To: " + message.ToEmail,
		"Subject: Verify your Pody account",
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=UTF-8",
		"",
		body,
	}, "\r\n")

	client, err := s.dialSMTP(addr)
	if err != nil {
		return err
	}
	defer client.Close()

	if err := s.authenticate(client); err != nil {
		return err
	}

	if err := client.Mail(s.cfg.EmailFrom); err != nil {
		return fmt.Errorf("set smtp sender: %w", err)
	}
	if err := client.Rcpt(message.ToEmail); err != nil {
		return fmt.Errorf("set smtp recipient: %w", err)
	}

	writer, err := client.Data()
	if err != nil {
		return fmt.Errorf("open smtp data writer: %w", err)
	}

	if _, err := writer.Write([]byte(raw)); err != nil {
		writer.Close()
		return fmt.Errorf("write smtp message: %w", err)
	}
	if err := writer.Close(); err != nil {
		return fmt.Errorf("close smtp data writer: %w", err)
	}

	if err := client.Quit(); err != nil {
		return fmt.Errorf("quit smtp session: %w", err)
	}

	return nil
}

func (s smtpSender) dialSMTP(addr string) (*smtp.Client, error) {
	timeout := s.cfg.DialTimeout
	if timeout <= 0 {
		timeout = 10 * time.Second
	}

	dialer := net.Dialer{Timeout: timeout}
	conn, err := dialer.Dial("tcp", addr)
	if err != nil {
		return nil, fmt.Errorf("dial smtp server: %w", err)
	}

	mode := strings.ToLower(strings.TrimSpace(s.cfg.TLSMode))
	if mode == "" {
		mode = "starttls"
	}

	if mode == "tls" || mode == "smtps" {
		tlsConn := tls.Client(conn, s.tlsConfig())
		if err := tlsConn.Handshake(); err != nil {
			conn.Close()
			return nil, fmt.Errorf("smtp tls handshake: %w", err)
		}
		client, err := smtp.NewClient(tlsConn, s.cfg.SMTPHost)
		if err != nil {
			tlsConn.Close()
			return nil, fmt.Errorf("create smtp client: %w", err)
		}
		return client, nil
	}

	client, err := smtp.NewClient(conn, s.cfg.SMTPHost)
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("create smtp client: %w", err)
	}

	if mode == "starttls" {
		ok, _ := client.Extension("STARTTLS")
		if !ok {
			client.Close()
			return nil, errors.New("smtp server does not support STARTTLS")
		}
		if err := client.StartTLS(s.tlsConfig()); err != nil {
			client.Close()
			return nil, fmt.Errorf("starttls failed: %w", err)
		}
	}

	return client, nil
}

func (s smtpSender) authenticate(client *smtp.Client) error {
	auth := smtp.PlainAuth("", s.cfg.SMTPUsername, s.cfg.SMTPPassword, s.cfg.SMTPHost)
	if ok, _ := client.Extension("AUTH"); !ok {
		return errors.New("smtp server does not support AUTH")
	}
	if err := client.Auth(auth); err != nil {
		return fmt.Errorf("smtp auth failed: %w", err)
	}
	return nil
}

func (s smtpSender) tlsConfig() *tls.Config {
	return &tls.Config{
		ServerName:         s.cfg.SMTPHost,
		InsecureSkipVerify: s.cfg.SkipVerify,
		MinVersion:         tls.VersionTLS12,
	}
}

func fallbackName(displayName, email string) string {
	displayName = strings.TrimSpace(displayName)
	if displayName != "" {
		return displayName
	}

	return strings.TrimSpace(email)
}
