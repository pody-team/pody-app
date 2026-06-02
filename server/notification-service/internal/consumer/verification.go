package consumer

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"strconv"
	"strings"
	"time"

	"github.com/promex04/pody/server/notification-service/internal/config"
	"github.com/promex04/pody/server/notification-service/internal/email"
	"github.com/promex04/pody/server/notification-service/internal/store"
	"github.com/segmentio/kafka-go"
)

const (
	// Header chuẩn hoá metadata retry trên Kafka message.
	headerAttempt        = "x-attempt"
	headerIdempotencyKey = "x-idempotency-key"
	headerLastError      = "x-last-error"
)

// VerificationRequestedEvent là payload event yêu cầu gửi email xác minh từ identity-service.
type VerificationRequestedEvent struct {
	EventID         string    `json:"event_id"`
	IdempotencyKey  string    `json:"idempotency_key"`
	EventType       string    `json:"event_type"`
	OccurredAt      time.Time `json:"occurred_at"`
	UserID          string    `json:"user_id"`
	ToEmail         string    `json:"to_email"`
	ToDisplayName   string    `json:"to_display_name"`
	VerificationURL string    `json:"verification_url"`
	ExpiresAt       time.Time `json:"expires_at"`
}

// messageReader trừu tượng hoá Kafka reader để dễ test.
type messageReader interface {
	FetchMessage(ctx context.Context) (kafka.Message, error)
	CommitMessages(ctx context.Context, messages ...kafka.Message) error
	Close() error
}

// messageWriter trừu tượng hoá Kafka writer để dễ test.
type messageWriter interface {
	WriteMessages(ctx context.Context, messages ...kafka.Message) error
	Close() error
}

// VerificationConsumer xử lý event verification, retry và DLQ.
type VerificationConsumer struct {
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

// NewVerificationConsumer khởi tạo consumer verification cùng reader/writer cho retry và DLQ.
func NewVerificationConsumer(cfg config.Config, logger *slog.Logger, sender email.Sender, processedStore store.ProcessedEventStore, deliveryLogs store.DeliveryLogStore) (*VerificationConsumer, error) {
	topics := []string{
		strings.TrimSpace(cfg.VerificationTopic),
		strings.TrimSpace(cfg.VerificationRetryTopic),
		strings.TrimSpace(cfg.VerificationDLQTopic),
	}

	if err := ensureTopics(cfg.KafkaBrokers, topics); err != nil {
		return nil, err
	}

	reader := kafka.NewReader(kafka.ReaderConfig{
		// External API: subscribe Kafka topic chính + retry topic.
		Brokers:        cfg.KafkaBrokers,
		GroupID:        strings.TrimSpace(cfg.VerificationConsumerGroup),
		GroupTopics:    []string{strings.TrimSpace(cfg.VerificationTopic), strings.TrimSpace(cfg.VerificationRetryTopic)},
		MinBytes:       1,
		MaxBytes:       10e6,
		CommitInterval: 0,
	})

	retryWriter := newWriter(cfg.KafkaBrokers, cfg.VerificationRetryTopic, cfg.KafkaClientID, cfg.KafkaWriteTimeout)
	dlqWriter := newWriter(cfg.KafkaBrokers, cfg.VerificationDLQTopic, cfg.KafkaClientID, cfg.KafkaWriteTimeout)

	return newVerificationConsumer(
		reader,
		retryWriter,
		dlqWriter,
		processedStore,
		deliveryLogs,
		logger,
		sender,
		cfg.VerificationRetryTopic,
		cfg.VerificationDLQTopic,
		cfg.VerificationMaxAttempts,
	), nil
}

// newVerificationConsumer tạo struct consumer với các dependency đã chuẩn bị sẵn.
func newVerificationConsumer(
	reader messageReader,
	retryWriter messageWriter,
	dlqWriter messageWriter,
	processedStore store.ProcessedEventStore,
	deliveryLogs store.DeliveryLogStore,
	logger *slog.Logger,
	sender email.Sender,
	retryTopic string,
	dlqTopic string,
	maxAttempts int,
) *VerificationConsumer {
	if maxAttempts <= 0 {
		maxAttempts = 5
	}

	return &VerificationConsumer{
		reader:        reader,
		retryWriter:   retryWriter,
		dlqWriter:     dlqWriter,
		store:         processedStore,
		deliveryLogs:  deliveryLogs,
		sender:        sender,
		logger:        logger,
		retryTopic:    strings.TrimSpace(retryTopic),
		dlqTopic:      strings.TrimSpace(dlqTopic),
		maxAttempts:   maxAttempts,
		sourceService: "identity-service",
	}
}

// newWriter tạo Kafka writer dùng chung cấu hình gửi message.
func newWriter(brokers []string, topic, clientID string, writeTimeout time.Duration) messageWriter {
	return &kafka.Writer{
		// External API: ghi message ra Kafka topic đích.
		Addr:                   kafka.TCP(brokers...),
		Topic:                  strings.TrimSpace(topic),
		Balancer:               &kafka.LeastBytes{},
		RequiredAcks:           kafka.RequireAll,
		AllowAutoTopicCreation: true,
		BatchTimeout:           10 * time.Millisecond,
		WriteTimeout:           writeTimeout,
		Transport: &kafka.Transport{
			ClientID: strings.TrimSpace(clientID),
		},
	}
}

// ensureTopics đảm bảo các topic cần thiết đã tồn tại trên Kafka cluster.
func ensureTopics(brokers []string, topics []string) error {
	if len(brokers) == 0 {
		return fmt.Errorf("KAFKA_BROKERS is required")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// External API: kết nối broker Kafka để lấy controller.
	conn, err := kafka.DialContext(ctx, "tcp", brokers[0])
	if err != nil {
		return fmt.Errorf("dial kafka broker: %w", err)
	}
	defer conn.Close()

	controller, err := conn.Controller()
	if err != nil {
		return fmt.Errorf("get kafka controller: %w", err)
	}

	// External API: kết nối Kafka controller để tạo topic.
	controllerConn, err := kafka.DialContext(ctx, "tcp", net.JoinHostPort(controller.Host, strconv.Itoa(controller.Port)))
	if err != nil {
		return fmt.Errorf("dial kafka controller: %w", err)
	}
	defer controllerConn.Close()

	configs := make([]kafka.TopicConfig, 0, len(topics))
	for _, topic := range topics {
		topic = strings.TrimSpace(topic)
		if topic == "" {
			continue
		}
		configs = append(configs, kafka.TopicConfig{
			Topic:             topic,
			NumPartitions:     1,
			ReplicationFactor: 1,
		})
	}

	if len(configs) == 0 {
		return fmt.Errorf("at least one kafka topic is required")
	}

	// External API: tạo topic trên Kafka nếu chưa tồn tại.
	err = controllerConn.CreateTopics(configs...)
	if err != nil && !strings.Contains(strings.ToLower(err.Error()), "already exists") {
		return fmt.Errorf("create kafka topics: %w", err)
	}

	return nil
}

// Run chạy vòng lặp đọc message verification cho đến khi context bị hủy hoặc có lỗi nghiêm trọng.
func (c *VerificationConsumer) Run(ctx context.Context) error {
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
			return fmt.Errorf("fetch verification event: %w", err)
		}

		if err := c.handleMessage(ctx, message); err != nil {
			return err
		}
	}
}

// handleMessage xử lý một event verification với idempotency, retry và DLQ.
func (c *VerificationConsumer) handleMessage(ctx context.Context, message kafka.Message) error {
	// Attempt được truyền qua header Kafka để giữ số lần thử khi consumer khởi động lại.
	attempt := messageAttempt(message)

	var event VerificationRequestedEvent
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
		c.logger.Info("verification event skipped as duplicate", "event_id", event.EventID, "email", event.ToEmail)
		return c.reader.CommitMessages(ctx, message)
	}

	// External API: gọi provider email (SMTP/log sender) để gửi thư xác minh.
	if err := c.sender.SendVerification(ctx, email.VerificationMessage{
		EventID:         event.EventID,
		IdempotencyKey:  event.IdempotencyKey,
		UserID:          event.UserID,
		ToEmail:         event.ToEmail,
		ToDisplayName:   event.ToDisplayName,
		VerificationURL: event.VerificationURL,
		ExpiresAt:       event.ExpiresAt,
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
			c.logger.Error("verification event moved to dlq",
				"event_id", event.EventID,
				"email", event.ToEmail,
				"attempt", attempt,
				"error", err,
			)
			return nil
		}

		if err := c.publishRetry(ctx, message, attempt+1, event.IdempotencyKey, err); err != nil {
			return err
		}
		if err := c.reader.CommitMessages(ctx, message); err != nil {
			return err
		}

		c.logger.Warn("verification event scheduled for retry",
			"event_id", event.EventID,
			"email", event.ToEmail,
			"attempt", attempt+1,
			"error", err,
		)
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

	c.logger.Info("verification event processed",
		"event_id", event.EventID,
		"event_type", event.EventType,
		"email", event.ToEmail,
	)
	return nil
}

// publishRetry đẩy message sang retry topic và cập nhật header số lần thử.
func (c *VerificationConsumer) publishRetry(ctx context.Context, message kafka.Message, attempt int, idempotencyKey string, cause error) error {
	headers := append(headersWithout(message.Headers, headerLastError),
		kafka.Header{Key: headerAttempt, Value: []byte(strconv.Itoa(attempt))},
		kafka.Header{Key: headerIdempotencyKey, Value: []byte(strings.TrimSpace(idempotencyKey))},
	)

	return c.retryWriter.WriteMessages(ctx, kafka.Message{
		Key:     message.Key,
		Value:   message.Value,
		Time:    time.Now().UTC(),
		Headers: headers,
	})
}

// publishDLQ đẩy message lỗi cuối cùng sang DLQ kèm thông tin lỗi.
func (c *VerificationConsumer) publishDLQ(ctx context.Context, message kafka.Message, attempt int, idempotencyKey string, cause error) error {
	headers := append(headersWithout(message.Headers, headerLastError),
		kafka.Header{Key: headerAttempt, Value: []byte(strconv.Itoa(attempt))},
		kafka.Header{Key: headerIdempotencyKey, Value: []byte(strings.TrimSpace(idempotencyKey))},
		kafka.Header{Key: headerLastError, Value: []byte(strings.TrimSpace(cause.Error()))},
	)

	return c.dlqWriter.WriteMessages(ctx, kafka.Message{
		Key:     message.Key,
		Value:   message.Value,
		Time:    time.Now().UTC(),
		Headers: headers,
	})
}

// messageAttempt đọc số lần thử từ header của Kafka message.
func messageAttempt(message kafka.Message) int {
	// Nếu header attempt thiếu hoặc sai định dạng thì coi như lần thử đầu tiên.
	for _, header := range message.Headers {
		if header.Key != headerAttempt {
			continue
		}

		attempt, err := strconv.Atoi(strings.TrimSpace(string(header.Value)))
		if err == nil && attempt > 0 {
			return attempt
		}
	}

	return 1
}

// headersWithout loại bỏ header theo key trước khi ghi lại message.
func headersWithout(headers []kafka.Header, key string) []kafka.Header {
	filtered := make([]kafka.Header, 0, len(headers))
	for _, header := range headers {
		if header.Key == key {
			continue
		}
		filtered = append(filtered, header)
	}
	return filtered
}
