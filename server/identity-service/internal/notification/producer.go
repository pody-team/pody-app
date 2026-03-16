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

const DefaultVerificationTopic = "identity.email.verification.requested"

type VerificationMessage struct {
	EventID         string    `json:"event_id,omitempty"`
	IdempotencyKey  string    `json:"idempotency_key,omitempty"`
	ToEmail         string    `json:"to_email"`
	ToDisplayName   string    `json:"to_display_name"`
	VerificationURL string    `json:"verification_url"`
	ExpiresAt       time.Time `json:"expires_at"`
}

type VerificationRequestedEvent struct {
	EventID         string    `json:"event_id"`
	IdempotencyKey  string    `json:"idempotency_key"`
	EventType       string    `json:"event_type"`
	OccurredAt      time.Time `json:"occurred_at"`
	ToEmail         string    `json:"to_email"`
	ToDisplayName   string    `json:"to_display_name"`
	VerificationURL string    `json:"verification_url"`
	ExpiresAt       time.Time `json:"expires_at"`
}

type VerificationSender interface {
	SendVerification(ctx context.Context, message VerificationMessage) error
}

type messageWriter interface {
	WriteMessages(ctx context.Context, messages ...kafka.Message) error
	Close() error
}

type Producer struct {
	topic  string
	writer messageWriter
}

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
		topic: topic,
		writer: &kafka.Writer{
			Addr:                   kafka.TCP(cleanedBrokers...),
			Topic:                  topic,
			Balancer:               &kafka.LeastBytes{},
			RequiredAcks:           kafka.RequireAll,
			AllowAutoTopicCreation: true,
			BatchTimeout:           10 * time.Millisecond,
			WriteTimeout:           writeTimeout,
			Async:                  false,
			Transport: &kafka.Transport{
				ClientID: strings.TrimSpace(clientID),
			},
		},
	}, nil
}

func newProducerWithWriter(topic string, writer messageWriter) *Producer {
	return &Producer{
		topic:  topic,
		writer: writer,
	}
}

func (p *Producer) SendVerification(ctx context.Context, message VerificationMessage) error {
	event := NewVerificationEvent(p.topic, message)

	payload, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("marshal verification event: %w", err)
	}

	if err := p.PublishPayload(ctx, event.IdempotencyKey, payload); err != nil {
		return fmt.Errorf("publish verification event: %w", err)
	}

	return nil
}

func (p *Producer) PublishPayload(ctx context.Context, key string, payload []byte) error {
	return p.writer.WriteMessages(ctx, kafka.Message{
		Key:   []byte(strings.TrimSpace(key)),
		Value: payload,
		Time:  time.Now().UTC(),
	})
}

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
		ToEmail:         message.ToEmail,
		ToDisplayName:   message.ToDisplayName,
		VerificationURL: message.VerificationURL,
		ExpiresAt:       message.ExpiresAt.UTC(),
	}
}

func (p *Producer) Close() error {
	if p == nil || p.writer == nil {
		return nil
	}

	return p.writer.Close()
}
