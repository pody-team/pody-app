package notification

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/segmentio/kafka-go"
)

const (
	DefaultVerificationTopic  = "identity.email.verification.requested"
	DefaultPasswordResetTopic = "identity.password.reset.requested"
	DefaultUserProfileTopic   = "identity.user.profile.updated"
)

// VerificationMessage chứa thông điệp thô của yêu cầu xác thực email.
type VerificationMessage struct {
	EventID         string    `json:"event_id,omitempty"`
	IdempotencyKey  string    `json:"idempotency_key,omitempty"`
	UserID          string    `json:"user_id"`
	ToEmail         string    `json:"to_email"`
	ToDisplayName   string    `json:"to_display_name"`
	VerificationURL string    `json:"verification_url"`
	ExpiresAt       time.Time `json:"expires_at"`
}

// VerificationRequestedEvent là cấu trúc sự kiện xác thực email gửi lên Kafka.
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

// PasswordResetMessage chứa thông điệp thô của yêu cầu đặt lại mật khẩu.
type PasswordResetMessage struct {
	EventID        string    `json:"event_id,omitempty"`
	IdempotencyKey string    `json:"idempotency_key,omitempty"`
	UserID         string    `json:"user_id"`
	ToEmail        string    `json:"to_email"`
	ToDisplayName  string    `json:"to_display_name"`
	ResetOTP       string    `json:"reset_otp"`
	ExpiresAt      time.Time `json:"expires_at"`
}

// PasswordResetRequestedEvent là cấu trúc sự kiện yêu cầu reset mật khẩu gửi lên Kafka.
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

// UserProfileUpdatedMessage chứa thông điệp thô của sự kiện cập nhật profile.
type UserProfileUpdatedMessage struct {
	EventID        string    `json:"event_id,omitempty"`
	IdempotencyKey string    `json:"idempotency_key,omitempty"`
	UserID         string    `json:"user_id"`
	DisplayName    string    `json:"display_name"`
	Username       string    `json:"username"`
	AvatarURL      string    `json:"avatar_url"`
	Bio            string    `json:"bio"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// UserProfileUpdatedEvent là cấu trúc sự kiện cập nhật profile gửi lên Kafka.
type UserProfileUpdatedEvent struct {
	EventID        string    `json:"event_id"`
	IdempotencyKey string    `json:"idempotency_key"`
	EventType      string    `json:"event_type"`
	OccurredAt     time.Time `json:"occurred_at"`
	UserID         string    `json:"user_id"`
	DisplayName    string    `json:"display_name"`
	Username       string    `json:"username"`
	AvatarURL      string    `json:"avatar_url"`
	Bio            string    `json:"bio"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// messageWriter định nghĩa interface cho việc ghi tin nhắn lên Kafka (để hỗ trợ unit test).
type messageWriter interface {
	WriteMessages(ctx context.Context, messages ...kafka.Message) error
	Close() error
}

// Producer đảm nhận việc kết nối và đẩy các event của Identity Service lên Kafka.
type Producer struct {
	defaultTopic string
	writer       messageWriter
}

// NewProducer khởi tạo Kafka Producer mới với cấu hình các brokers, topic và client ID.
func NewProducer(brokers []string, topic, clientID string, writeTimeout time.Duration) (*Producer, error) {
	if len(brokers) == 0 {
		return nil, fmt.Errorf("KAFKA_BROKERS is required")
	}

	cleanedBrokers := make([]string, 0, len(brokers))
	for _, broker := range brokers {
		broker = strings.TrimSpace(broker)
		if broker != "" {
			cleanedBrokers = append(cleanedBrokers, broker)
		}
	}

	if len(cleanedBrokers) == 0 {
		return nil, fmt.Errorf("KAFKA_BROKERS is required")
	}

	topic = strings.TrimSpace(topic)
	if topic == "" {
		topic = DefaultVerificationTopic
	}

	return &Producer{
		defaultTopic: topic,
		writer: &kafka.Writer{
			Addr:                   kafka.TCP(cleanedBrokers...),
			Balancer:               &kafka.LeastBytes{},
			RequiredAcks:           kafka.RequireAll, // Đảm bảo ghi thành công xuống tất cả replicas
			AllowAutoTopicCreation: true,            // Tự động tạo topic nếu chưa tồn tại
			BatchTimeout:           10 * time.Millisecond,
			WriteTimeout:           writeTimeout,
			Async:                  false,
			Transport: &kafka.Transport{
				ClientID: strings.TrimSpace(clientID),
			},
		},
	}, nil
}

// newProducerWithWriter khởi tạo đối tượng Producer trực tiếp từ Writer truyền vào (phục vụ mocking test).
func newProducerWithWriter(topic string, writer messageWriter) *Producer {
	return &Producer{
		defaultTopic: strings.TrimSpace(topic),
		writer:       writer,
	}
}

// SendVerification xuất bản sự kiện xác minh email lên Kafka.
func (p *Producer) SendVerification(ctx context.Context, message VerificationMessage) error {
	event := NewVerificationEvent(p.defaultTopic, message)

	payload, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("marshal verification event: %w", err)
	}

	if err := p.PublishPayload(ctx, TopicFromEventType(event.EventType), event.IdempotencyKey, payload); err != nil {
		return fmt.Errorf("publish verification event: %w", err)
	}

	return nil
}

// SendPasswordReset xuất bản sự kiện yêu cầu reset mật khẩu lên Kafka.
func (p *Producer) SendPasswordReset(ctx context.Context, message PasswordResetMessage) error {
	event := NewPasswordResetEvent(DefaultPasswordResetTopic, message)

	payload, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("marshal password reset event: %w", err)
	}

	if err := p.PublishPayload(ctx, TopicFromEventType(event.EventType), event.IdempotencyKey, payload); err != nil {
		return fmt.Errorf("publish password reset event: %w", err)
	}

	return nil
}

// PublishPayload đóng vai trò gửi trực tiếp chuỗi payload nhị phân lên Kafka topic.
func (p *Producer) PublishPayload(ctx context.Context, topic, key string, payload []byte) error {
	topic = strings.TrimSpace(topic)
	if topic == "" {
		topic = p.defaultTopic
	}

	return p.writer.WriteMessages(ctx, kafka.Message{
		Topic: topic,
		Key:   []byte(strings.TrimSpace(key)),
		Value: payload,
		Time:  time.Now().UTC(),
	})
}

// NewVerificationEvent chuyển đổi cấu trúc VerificationMessage thành struct VerificationRequestedEvent hoàn chỉnh.
func NewVerificationEvent(topic string, message VerificationMessage) VerificationRequestedEvent {
	eventID := strings.TrimSpace(message.EventID)
	if eventID == "" {
		eventID = uuid.NewString()
	}

	idempotencyKey := strings.TrimSpace(message.IdempotencyKey)
	if idempotencyKey == "" {
		idempotencyKey = eventID
	}

	return VerificationRequestedEvent{
		EventID:         eventID,
		IdempotencyKey:  idempotencyKey,
		EventType:       strings.TrimSpace(topic) + ".v1",
		OccurredAt:      time.Now().UTC(),
		UserID:          strings.TrimSpace(message.UserID),
		ToEmail:         message.ToEmail,
		ToDisplayName:   message.ToDisplayName,
		VerificationURL: message.VerificationURL,
		ExpiresAt:       message.ExpiresAt.UTC(),
	}
}

// NewPasswordResetEvent chuyển đổi cấu trúc PasswordResetMessage thành struct PasswordResetRequestedEvent hoàn chỉnh.
func NewPasswordResetEvent(topic string, message PasswordResetMessage) PasswordResetRequestedEvent {
	eventID := strings.TrimSpace(message.EventID)
	if eventID == "" {
		eventID = uuid.NewString()
	}

	idempotencyKey := strings.TrimSpace(message.IdempotencyKey)
	if idempotencyKey == "" {
		idempotencyKey = eventID
	}

	if strings.TrimSpace(topic) == "" {
		topic = DefaultPasswordResetTopic
	}

	return PasswordResetRequestedEvent{
		EventID:        eventID,
		IdempotencyKey: idempotencyKey,
		EventType:      strings.TrimSpace(topic) + ".v1",
		OccurredAt:     time.Now().UTC(),
		UserID:         strings.TrimSpace(message.UserID),
		ToEmail:        message.ToEmail,
		ToDisplayName:  message.ToDisplayName,
		ResetOTP:       message.ResetOTP,
		ExpiresAt:      message.ExpiresAt.UTC(),
	}
}

// NewUserProfileUpdatedEvent chuyển đổi cấu trúc UserProfileUpdatedMessage thành struct UserProfileUpdatedEvent hoàn chỉnh.
func NewUserProfileUpdatedEvent(topic string, message UserProfileUpdatedMessage) UserProfileUpdatedEvent {
	eventID := strings.TrimSpace(message.EventID)
	if eventID == "" {
		eventID = uuid.NewString()
	}

	idempotencyKey := strings.TrimSpace(message.IdempotencyKey)
	if idempotencyKey == "" {
		idempotencyKey = eventID
	}

	if strings.TrimSpace(topic) == "" {
		topic = DefaultUserProfileTopic
	}

	return UserProfileUpdatedEvent{
		EventID:        eventID,
		IdempotencyKey: idempotencyKey,
		EventType:      strings.TrimSpace(topic) + ".v1",
		OccurredAt:     time.Now().UTC(),
		UserID:         strings.TrimSpace(message.UserID),
		DisplayName:    strings.TrimSpace(message.DisplayName),
		Username:       strings.TrimSpace(message.Username),
		AvatarURL:      strings.TrimSpace(message.AvatarURL),
		Bio:            message.Bio,
		UpdatedAt:      message.UpdatedAt.UTC(),
	}
}

// TopicFromEventType trích xuất tên topic từ trường EventType (bằng cách cắt đuôi ".v1").
func TopicFromEventType(eventType string) string {
	eventType = strings.TrimSpace(eventType)
	if strings.HasSuffix(eventType, ".v1") {
		return strings.TrimSuffix(eventType, ".v1")
	}
	return eventType
}

// Close thực hiện đóng kết nối Kafka Writer an toàn khi dừng chương trình.
func (p *Producer) Close() error {
	if p == nil || p.writer == nil {
		return nil
	}

	return p.writer.Close()
}

