package consumer

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"strconv"
	"time"

	"github.com/promex04/pody/server/notification-service/internal/config"
	"github.com/promex04/pody/server/notification-service/internal/email"
	"github.com/promex04/pody/server/notification-service/internal/store"
	"github.com/segmentio/kafka-go"
)

// PasswordResetRequestedEvent là payload event yêu cầu gửi OTP đặt lại mật khẩu.
type PasswordResetRequestedEvent struct {
	EventID        string    `json:"event_id"`
	IdempotencyKey string    `json:"idempotency_key"`
	EventType      string    `json:"event_type"`
	OccurredAt     time.Time `json:"occurred_at"`
	UserID         string    `json:"user_id"`
	ToEmail        string    `json:"to_email"`
	ToDisplayName  string    `json:"to_display_name"`
	ResetOTP       string    `json:"reset_otp"`
	ExpiresAt      time.Time `json:"expires_at"`
}

// PasswordResetConsumer xử lý event password reset, retry và DLQ.
type PasswordResetConsumer struct {
	reader        messageReader
	retryWriter   messageWriter
	dlqWriter     messageWriter
	store         store.ProcessedEventStore
	deliveryLogs  store.DeliveryLogStore
	sender        email.Sender
	logger        *slog.Logger
	retryTopic    string
	dlqTopic      string
	maxAttempts   int
	sourceService string
}

// NewPasswordResetConsumer khởi tạo consumer password reset cùng reader/writer cho retry và DLQ.
func NewPasswordResetConsumer(cfg config.Config, logger *slog.Logger, sender email.Sender, processedStore store.ProcessedEventStore, deliveryLogs store.DeliveryLogStore) (*PasswordResetConsumer, error) {
	topics := []string{
		cfg.PasswordResetTopic,
		cfg.PasswordResetRetryTopic,
		cfg.PasswordResetDLQTopic,
	}

	if err := ensureTopics(cfg.KafkaBrokers, topics); err != nil {
		return nil, err
	}

	reader := kafka.NewReader(kafka.ReaderConfig{
		// External API: subscribe Kafka topic chính + retry topic.
		Brokers:        cfg.KafkaBrokers,
		GroupID:        cfg.PasswordResetConsumerGroup,
		GroupTopics:    []string{cfg.PasswordResetTopic, cfg.PasswordResetRetryTopic},
		MinBytes:       1,
		MaxBytes:       10e6,
		CommitInterval: 0,
	})

	retryWriter := newWriter(cfg.KafkaBrokers, cfg.PasswordResetRetryTopic, cfg.KafkaClientID, cfg.KafkaWriteTimeout)
	dlqWriter := newWriter(cfg.KafkaBrokers, cfg.PasswordResetDLQTopic, cfg.KafkaClientID, cfg.KafkaWriteTimeout)

	return &PasswordResetConsumer{
		reader:        reader,
		retryWriter:   retryWriter,
		dlqWriter:     dlqWriter,
		store:         processedStore,
		deliveryLogs:  deliveryLogs,
		sender:        sender,
		logger:        logger,
		retryTopic:    cfg.PasswordResetRetryTopic,
		dlqTopic:      cfg.PasswordResetDLQTopic,
		maxAttempts:   cfg.PasswordResetMaxAttempts,
		sourceService: "identity-service",
	}, nil
}

// Run chạy vòng lặp đọc message password reset cho đến khi context bị hủy hoặc có lỗi.
func (c *PasswordResetConsumer) Run(ctx context.Context) error {
	defer c.reader.Close()
	defer c.retryWriter.Close()
	defer c.dlqWriter.Close()

	for {
		// External API: đọc message từ Kafka.
		message, err := c.reader.FetchMessage(ctx)
		if err != nil {
			if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) || ctx.Err() != nil {
				return nil
			}
			return err
		}

		if err := c.handleMessage(ctx, message); err != nil {
			return err
		}
	}
}

// handleMessage xử lý một event password reset với idempotency, retry và DLQ.
func (c *PasswordResetConsumer) handleMessage(ctx context.Context, message kafka.Message) error {
	// Attempt được truyền qua header Kafka để giữ số lần thử khi consumer khởi động lại.
	attempt := messageAttempt(message)

	var event PasswordResetRequestedEvent
	if err := json.Unmarshal(message.Value, &event); err != nil {
		if err := c.publishDLQ(ctx, message, attempt, "", err); err != nil {
			return err
		}
		return c.reader.CommitMessages(ctx, message)
	}

	if event.IdempotencyKey == "" {
		event.IdempotencyKey = event.EventID
	}

	processed, err := c.store.HasProcessedEvent(ctx, event.EventID)
	if err != nil {
		return err
	}
	if processed {
		c.logger.Info("password reset event skipped as duplicate", "event_id", event.EventID, "email", event.ToEmail)
		return c.reader.CommitMessages(ctx, message)
	}

	// External API: gọi provider email (SMTP/log sender) để gửi OTP reset password.
	if err := c.sender.SendPasswordReset(ctx, email.PasswordResetMessage{
		EventID:        event.EventID,
		IdempotencyKey: event.IdempotencyKey,
		UserID:         event.UserID,
		ToEmail:        event.ToEmail,
		ToDisplayName:  event.ToDisplayName,
		ResetOTP:       event.ResetOTP,
		ExpiresAt:      event.ExpiresAt,
	}); err != nil {
		_ = c.deliveryLogs.CreateEmailDeliveryLog(ctx, store.CreateDeliveryLogInput{
			UserID:            event.UserID,
			Provider:          c.sender.ProviderName(),
			DeliveryStatus:    "failed",
			ProviderMessageID: event.EventID,
			ErrorMessage:      err.Error(),
		})

		// Gửi thất bại sẽ retry đến maxAttempts, sau đó đẩy vào DLQ để xử lý thủ công.
		if attempt >= c.maxAttempts {
			if err := c.publishDLQ(ctx, message, attempt, event.IdempotencyKey, err); err != nil {
				return err
			}
			if err := c.reader.CommitMessages(ctx, message); err != nil {
				return err
			}
			c.logger.Error("password reset event moved to dlq", "event_id", event.EventID, "email", event.ToEmail, "attempt", attempt, "error", err)
			return nil
		}

		if err := c.publishRetry(ctx, message, attempt+1, event.IdempotencyKey, err); err != nil {
			return err
		}
		if err := c.reader.CommitMessages(ctx, message); err != nil {
			return err
		}

		c.logger.Warn("password reset event scheduled for retry", "event_id", event.EventID, "email", event.ToEmail, "attempt", attempt+1, "error", err)
		return nil
	}

	if err := c.store.MarkProcessedEvent(ctx, event.EventID, c.sourceService, event.EventType); err != nil {
		return err
	}

	// Ghi log gửi thành công để dễ quan sát và phục vụ debug.
	deliveredAt := time.Now().UTC()
	if err := c.deliveryLogs.CreateEmailDeliveryLog(ctx, store.CreateDeliveryLogInput{
		UserID:            event.UserID,
		Provider:          c.sender.ProviderName(),
		DeliveryStatus:    "sent",
		ProviderMessageID: event.EventID,
		DeliveredAt:       &deliveredAt,
	}); err != nil {
		return err
	}

	if err := c.reader.CommitMessages(ctx, message); err != nil {
		return err
	}

	c.logger.Info("password reset event processed", "event_id", event.EventID, "event_type", event.EventType, "email", event.ToEmail)
	return nil
}

// publishRetry đẩy message sang retry topic và cập nhật header số lần thử.
func (c *PasswordResetConsumer) publishRetry(ctx context.Context, message kafka.Message, attempt int, idempotencyKey string, _ error) error {
	headers := append(headersWithout(message.Headers, headerLastError),
		kafka.Header{Key: headerAttempt, Value: []byte(stringifyAttempt(attempt))},
		kafka.Header{Key: headerIdempotencyKey, Value: []byte(idempotencyKey)},
	)

	return c.retryWriter.WriteMessages(ctx, kafka.Message{
		Key:     message.Key,
		Value:   message.Value,
		Time:    time.Now().UTC(),
		Headers: headers,
	})
}

// publishDLQ đẩy message lỗi cuối cùng sang DLQ kèm thông tin lỗi.
func (c *PasswordResetConsumer) publishDLQ(ctx context.Context, message kafka.Message, attempt int, idempotencyKey string, cause error) error {
	headers := append(headersWithout(message.Headers, headerLastError),
		kafka.Header{Key: headerAttempt, Value: []byte(stringifyAttempt(attempt))},
		kafka.Header{Key: headerIdempotencyKey, Value: []byte(idempotencyKey)},
		kafka.Header{Key: headerLastError, Value: []byte(cause.Error())},
	)

	return c.dlqWriter.WriteMessages(ctx, kafka.Message{
		Key:     message.Key,
		Value:   message.Value,
		Time:    time.Now().UTC(),
		Headers: headers,
	})
}

// stringifyAttempt chuẩn hóa attempt thành chuỗi hợp lệ để lưu vào header.
func stringifyAttempt(attempt int) string {
	if attempt <= 0 {
		attempt = 1
	}
	return strconv.Itoa(attempt)
}
