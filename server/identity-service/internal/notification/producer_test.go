package notification

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/segmentio/kafka-go"
)

type fakeWriter struct {
	messages []kafka.Message
	err      error
	closed   bool
}

func (f *fakeWriter) WriteMessages(_ context.Context, messages ...kafka.Message) error {
	if f.err != nil {
		return f.err
	}

	f.messages = append(f.messages, messages...)
	return nil
}

func (f *fakeWriter) Close() error {
	f.closed = true
	return nil
}

func TestProducerSendVerification(t *testing.T) {
	writer := &fakeWriter{}
	producer := newProducerWithWriter(DefaultVerificationTopic, writer)

	err := producer.SendVerification(context.Background(), VerificationMessage{
		UserID:          "user-1",
		ToEmail:         "hello@pody.vn",
		ToDisplayName:   "Promex",
		VerificationURL: "http://localhost:8080/api/v1/public/identity/verify-email?token=abc",
		ExpiresAt:       time.Date(2026, time.March, 16, 12, 0, 0, 0, time.UTC),
	})
	if err != nil {
		t.Fatalf("SendVerification() error = %v", err)
	}

	if len(writer.messages) != 1 {
		t.Fatalf("expected one kafka message, got %d", len(writer.messages))
	}

	var event VerificationRequestedEvent
	if err := json.Unmarshal(writer.messages[0].Value, &event); err != nil {
		t.Fatalf("unmarshal event: %v", err)
	}

	if event.EventID == "" || event.EventType == "" {
		t.Fatalf("expected event metadata to be populated, got %+v", event)
	}

	if string(writer.messages[0].Key) != event.IdempotencyKey {
		t.Fatalf("expected kafka key to match idempotency key, got %q", string(writer.messages[0].Key))
	}

	if writer.messages[0].Topic != DefaultVerificationTopic {
		t.Fatalf("expected kafka topic %q, got %q", DefaultVerificationTopic, writer.messages[0].Topic)
	}

	if event.ToEmail != "hello@pody.vn" || event.VerificationURL == "" {
		t.Fatalf("unexpected event payload: %+v", event)
	}
}

func TestProducerSendVerificationPropagatesWriterError(t *testing.T) {
	producer := newProducerWithWriter(DefaultVerificationTopic, &fakeWriter{err: errors.New("boom")})

	err := producer.SendVerification(context.Background(), VerificationMessage{
		UserID:          "user-1",
		ToEmail:         "hello@pody.vn",
		VerificationURL: "http://localhost:8080/api/v1/public/identity/verify-email?token=abc",
		ExpiresAt:       time.Now().UTC().Add(time.Hour),
	})
	if err == nil {
		t.Fatal("expected writer error")
	}
}

func TestProducerSendPasswordReset(t *testing.T) {
	writer := &fakeWriter{}
	producer := newProducerWithWriter(DefaultVerificationTopic, writer)

	err := producer.SendPasswordReset(context.Background(), PasswordResetMessage{
		UserID:        "user-1",
		ToEmail:       "hello@pody.vn",
		ToDisplayName: "Promex",
		ResetOTP:      "123456",
		ExpiresAt:     time.Date(2026, time.March, 16, 12, 0, 0, 0, time.UTC),
	})
	if err != nil {
		t.Fatalf("SendPasswordReset() error = %v", err)
	}

	if len(writer.messages) != 1 {
		t.Fatalf("expected one kafka message, got %d", len(writer.messages))
	}

	var event PasswordResetRequestedEvent
	if err := json.Unmarshal(writer.messages[0].Value, &event); err != nil {
		t.Fatalf("unmarshal event: %v", err)
	}

	if writer.messages[0].Topic != DefaultPasswordResetTopic {
		t.Fatalf("expected kafka topic %q, got %q", DefaultPasswordResetTopic, writer.messages[0].Topic)
	}

	if event.UserID != "user-1" || event.ResetOTP == "" {
		t.Fatalf("unexpected event payload: %+v", event)
	}
}
