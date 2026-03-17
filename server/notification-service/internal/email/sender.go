package email

import (
	"bytes"
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
	UserID          string    `json:"user_id,omitempty"`
	ToEmail         string    `json:"to_email"`
	ToDisplayName   string    `json:"to_display_name"`
	VerificationURL string    `json:"verification_url"`
	ExpiresAt       time.Time `json:"expires_at"`
}

type PasswordResetMessage struct {
	EventID        string    `json:"event_id,omitempty"`
	IdempotencyKey string    `json:"idempotency_key,omitempty"`
	UserID         string    `json:"user_id,omitempty"`
	ToEmail        string    `json:"to_email"`
	ToDisplayName  string    `json:"to_display_name"`
	ResetOTP       string    `json:"reset_otp"`
	ExpiresAt      time.Time `json:"expires_at"`
}

type Sender interface {
	SendVerification(ctx context.Context, message VerificationMessage) error
	SendPasswordReset(ctx context.Context, message PasswordResetMessage) error
	ProviderName() string
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

func (s logSender) ProviderName() string {
	return "log"
}

func (s logSender) SendVerification(_ context.Context, message VerificationMessage) error {
	s.logger.Info("verification email dispatched",
		"email", message.ToEmail,
		"verification_url", message.VerificationURL,
		"expires_at", message.ExpiresAt.Format(time.RFC3339),
	)
	return nil
}

func (s logSender) SendPasswordReset(_ context.Context, message PasswordResetMessage) error {
	s.logger.Info("password reset email dispatched",
		"email", message.ToEmail,
		"reset_otp", message.ResetOTP,
		"expires_at", message.ExpiresAt.Format(time.RFC3339),
	)
	return nil
}

type smtpSender struct {
	cfg Config
}

func (s smtpSender) ProviderName() string {
	return "smtp"
}

func (s smtpSender) SendVerification(_ context.Context, message VerificationMessage) error {
	subject, textBody, htmlBody, err := RenderVerificationTemplate(
		fallbackName(message.ToDisplayName, message.ToEmail),
		message.VerificationURL,
		message.ExpiresAt,
	)
	if err != nil {
		return err
	}

	return s.sendEmail(message.ToEmail, subject, textBody, htmlBody)
}

func (s smtpSender) SendPasswordReset(_ context.Context, message PasswordResetMessage) error {
	subject, textBody, htmlBody, err := RenderPasswordResetTemplate(
		fallbackName(message.ToDisplayName, message.ToEmail),
		message.ResetOTP,
		message.ExpiresAt,
	)
	if err != nil {
		return err
	}

	return s.sendEmail(message.ToEmail, subject, textBody, htmlBody)
}

func (s smtpSender) sendEmail(toEmail, subject, textBody, htmlBody string) error {
	addr := s.cfg.SMTPHost + ":" + s.cfg.SMTPPort

	raw, err := buildMultipartMessage(
		s.cfg.EmailFrom,
		strings.TrimSpace(toEmail),
		strings.TrimSpace(subject),
		textBody,
		htmlBody,
	)
	if err != nil {
		return err
	}

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
	if err := client.Rcpt(strings.TrimSpace(toEmail)); err != nil {
		return fmt.Errorf("set smtp recipient: %w", err)
	}

	writer, err := client.Data()
	if err != nil {
		return fmt.Errorf("open smtp data writer: %w", err)
	}

	if _, err := writer.Write(raw); err != nil {
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

func buildMultipartMessage(fromEmail, toEmail, subject, textBody, htmlBody string) ([]byte, error) {
	boundary := fmt.Sprintf("pody-boundary-%d", time.Now().UnixNano())
	var buffer bytes.Buffer

	lines := []string{
		"From: " + strings.TrimSpace(fromEmail),
		"To: " + strings.TrimSpace(toEmail),
		"Subject: " + strings.TrimSpace(subject),
		"MIME-Version: 1.0",
		`Content-Type: multipart/alternative; boundary="` + boundary + `"`,
		"",
		"--" + boundary,
		"Content-Type: text/plain; charset=UTF-8",
		"Content-Transfer-Encoding: 8bit",
		"",
		textBody,
		"--" + boundary,
		"Content-Type: text/html; charset=UTF-8",
		"Content-Transfer-Encoding: 8bit",
		"",
		htmlBody,
		"--" + boundary + "--",
		"",
	}

	if _, err := buffer.WriteString(strings.Join(lines, "\r\n")); err != nil {
		return nil, fmt.Errorf("build multipart email: %w", err)
	}

	return buffer.Bytes(), nil
}
