package consumer

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/promex04/pody/server/notification-service/internal/email"
	"github.com/promex04/pody/server/notification-service/internal/store"
	"github.com/segmentio/kafka-go"
)

type fakeReader struct {
	messages   []kafka.Message
	fetchErr   error
	committed  []kafka.Message
	closeCalls int
	index      int
}

func (f *fakeReader) FetchMessage(_ context.Context) (kafka.Message, error) {
	if f.fetchErr != nil {
		return kafka.Message{}, f.fetchErr
	}

	if f.index >= len(f.messages) {
		return kafka.Message{}, context.Canceled
	}

	message := f.messages[f.index]
	f.index++
	return message, nil
}

func (f *fakeReader) CommitMessages(_ context.Context, messages ...kafka.Message) error {
	f.committed = append(f.committed, messages...)
	return nil
}

func (f *fakeReader) Close() error {
	f.closeCalls++
	return nil
}

type fakeWriter struct {
	messages []kafka.Message
	err      error
}

func (f *fakeWriter) WriteMessages(_ context.Context, messages ...kafka.Message) error {
	if f.err != nil {
		return f.err
	}

	f.messages = append(f.messages, messages...)
	return nil
}

func (f *fakeWriter) Close() error {
	return nil
}

type fakeEmailSender struct {
	messages       []email.VerificationMessage
	passwordResets []email.PasswordResetMessage
	err            error
}

func (f *fakeEmailSender) SendVerification(_ context.Context, message email.VerificationMessage) error {
	if f.err != nil {
		return f.err
	}

	f.messages = append(f.messages, message)
	return nil
}

func (f *fakeEmailSender) SendPasswordReset(_ context.Context, message email.PasswordResetMessage) error {
	if f.err != nil {
		return f.err
	}

	f.passwordResets = append(f.passwordResets, message)
	return nil
}

func (f *fakeEmailSender) ProviderName() string {
	return "smtp"
}

type fakeProcessedStore struct {
	processed map[string]bool
}

func newFakeProcessedStore() *fakeProcessedStore {
	return &fakeProcessedStore{processed: map[string]bool{}}
}

func (f *fakeProcessedStore) HasProcessedEvent(_ context.Context, eventID string) (bool, error) {
	return f.processed[eventID], nil
}

func (f *fakeProcessedStore) MarkProcessedEvent(_ context.Context, eventID, _ string, _ string) error {
	f.processed[eventID] = true
	return nil
}

func (f *fakeProcessedStore) DeleteProcessedEventsBefore(_ context.Context, _ time.Time, _ int) (int64, error) {
	return 0, nil
}

type fakeDeliveryLogStore struct {
	logs []store.CreateDeliveryLogInput
}

func (f *fakeDeliveryLogStore) CreateEmailDeliveryLog(_ context.Context, input store.CreateDeliveryLogInput) error {
	f.logs = append(f.logs, input)
	return nil
}

func TestVerificationConsumerRun(t *testing.T) {
	reader := &fakeReader{
		messages: []kafka.Message{{
			Value: []byte(`{"event_id":"evt-1","idempotency_key":"evt-1","event_type":"identity.email.verification.requested.v1","to_email":"hello@pody.vn","to_display_name":"Promex","verification_url":"http://localhost/verify","expires_at":"2026-03-16T12:00:00Z"}`),
		}},
	}
	sender := &fakeEmailSender{}
	deliveryLogs := &fakeDeliveryLogStore{}
	consumer := newVerificationConsumer(
		reader,
		&fakeWriter{},
		&fakeWriter{},
		newFakeProcessedStore(),
		deliveryLogs,
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		sender,
		"retry-topic",
		"dlq-topic",
		5,
	)

	if err := consumer.Run(context.Background()); err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	if len(sender.messages) != 1 {
		t.Fatalf("expected one email message, got %d", len(sender.messages))
	}

	if len(reader.committed) != 1 {
		t.Fatalf("expected one committed kafka message, got %d", len(reader.committed))
	}

	if len(deliveryLogs.logs) != 1 || deliveryLogs.logs[0].DeliveryStatus != "sent" {
		t.Fatalf("expected one sent delivery log, got %+v", deliveryLogs.logs)
	}
}

func TestVerificationConsumerSkipsDuplicate(t *testing.T) {
	reader := &fakeReader{
		messages: []kafka.Message{{
			Value: []byte(`{"event_id":"evt-1","idempotency_key":"evt-1","event_type":"identity.email.verification.requested.v1","to_email":"hello@pody.vn","verification_url":"http://localhost/verify","expires_at":"2026-03-16T12:00:00Z"}`),
		}},
	}
	processedStore := newFakeProcessedStore()
	processedStore.processed["evt-1"] = true
	sender := &fakeEmailSender{}
	consumer := newVerificationConsumer(
		reader,
		&fakeWriter{},
		&fakeWriter{},
		processedStore,
		&fakeDeliveryLogStore{},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		sender,
		"retry-topic",
		"dlq-topic",
		5,
	)

	if err := consumer.Run(context.Background()); err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	if len(sender.messages) != 0 {
		t.Fatalf("expected duplicate event to be skipped")
	}
}

func TestVerificationConsumerSendsRetryOnTemporaryFailure(t *testing.T) {
	reader := &fakeReader{
		messages: []kafka.Message{{
			Key:   []byte("evt-1"),
			Value: []byte(`{"event_id":"evt-1","idempotency_key":"evt-1","event_type":"identity.email.verification.requested.v1","to_email":"hello@pody.vn","verification_url":"http://localhost/verify","expires_at":"2026-03-16T12:00:00Z"}`),
		}},
	}
	retryWriter := &fakeWriter{}
	sender := &fakeEmailSender{err: errors.New("smtp failed")}
	deliveryLogs := &fakeDeliveryLogStore{}
	consumer := newVerificationConsumer(
		reader,
		retryWriter,
		&fakeWriter{},
		newFakeProcessedStore(),
		deliveryLogs,
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		sender,
		"retry-topic",
		"dlq-topic",
		5,
	)

	if err := consumer.Run(context.Background()); err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	if len(retryWriter.messages) != 1 {
		t.Fatalf("expected one retry message, got %d", len(retryWriter.messages))
	}

	if messageAttempt(retryWriter.messages[0]) != 2 {
		t.Fatalf("expected retry attempt to be 2")
	}

	if len(deliveryLogs.logs) != 1 || deliveryLogs.logs[0].DeliveryStatus != "failed" {
		t.Fatalf("expected one failed delivery log, got %+v", deliveryLogs.logs)
	}
}

func TestVerificationConsumerSendsDLQWhenAttemptsExceeded(t *testing.T) {
	reader := &fakeReader{
		messages: []kafka.Message{{
			Key:     []byte("evt-1"),
			Value:   []byte(`{"event_id":"evt-1","idempotency_key":"evt-1","event_type":"identity.email.verification.requested.v1","to_email":"hello@pody.vn","verification_url":"http://localhost/verify","expires_at":"2026-03-16T12:00:00Z"}`),
			Headers: []kafka.Header{{Key: headerAttempt, Value: []byte("5")}},
		}},
	}
	dlqWriter := &fakeWriter{}
	sender := &fakeEmailSender{err: errors.New("smtp failed")}
	deliveryLogs := &fakeDeliveryLogStore{}
	consumer := newVerificationConsumer(
		reader,
		&fakeWriter{},
		dlqWriter,
		newFakeProcessedStore(),
		deliveryLogs,
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		sender,
		"retry-topic",
		"dlq-topic",
		5,
	)

	if err := consumer.Run(context.Background()); err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	if len(dlqWriter.messages) != 1 {
		t.Fatalf("expected one dlq message, got %d", len(dlqWriter.messages))
	}

	if len(deliveryLogs.logs) != 1 || deliveryLogs.logs[0].DeliveryStatus != "failed" {
		t.Fatalf("expected one failed delivery log, got %+v", deliveryLogs.logs)
	}
}

func TestVerificationConsumerMovesInvalidPayloadToDLQ(t *testing.T) {
	reader := &fakeReader{
		messages: []kafka.Message{{
			Key:   []byte("evt-1"),
			Value: []byte(`not-json`),
		}},
	}
	dlqWriter := &fakeWriter{}
	consumer := newVerificationConsumer(
		reader,
		&fakeWriter{},
		dlqWriter,
		newFakeProcessedStore(),
		&fakeDeliveryLogStore{},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		&fakeEmailSender{},
		"retry-topic",
		"dlq-topic",
		5,
	)

	if err := consumer.Run(context.Background()); err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	if len(dlqWriter.messages) != 1 {
		t.Fatalf("expected one dlq message for invalid payload, got %d", len(dlqWriter.messages))
	}
}

func TestVerificationConsumerStopsOnContextCancel(t *testing.T) {
	reader := &fakeReader{fetchErr: context.Canceled}
	consumer := newVerificationConsumer(
		reader,
		&fakeWriter{},
		&fakeWriter{},
		newFakeProcessedStore(),
		&fakeDeliveryLogStore{},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		&fakeEmailSender{},
		"retry-topic",
		"dlq-topic",
		5,
	)

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	if err := consumer.Run(ctx); err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	if reader.closeCalls != 1 {
		t.Fatalf("expected reader to be closed once, got %d", reader.closeCalls)
	}
}

var _ store.ProcessedEventStore = (*fakeProcessedStore)(nil)
var _ store.DeliveryLogStore = (*fakeDeliveryLogStore)(nil)
var _ email.Sender = (*fakeEmailSender)(nil)
