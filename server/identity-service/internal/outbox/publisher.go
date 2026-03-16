package outbox

import (
	"context"
	"log/slog"
	"time"

	"github.com/promex04/pody/server/identity-service/internal/notification"
	"github.com/promex04/pody/server/identity-service/internal/store"
)

type Publisher struct {
	repo         store.Repository
	producer     *notification.Producer
	logger       *slog.Logger
	pollInterval time.Duration
	batchSize    int
}

func NewPublisher(repo store.Repository, producer *notification.Producer, logger *slog.Logger, pollInterval time.Duration, batchSize int) *Publisher {
	if pollInterval <= 0 {
		pollInterval = time.Second
	}

	if batchSize <= 0 {
		batchSize = 20
	}

	return &Publisher{
		repo:         repo,
		producer:     producer,
		logger:       logger,
		pollInterval: pollInterval,
		batchSize:    batchSize,
	}
}

func (p *Publisher) Run(ctx context.Context) error {
	if err := p.flush(ctx); err != nil && ctx.Err() == nil {
		p.logger.Error("outbox flush failed", "error", err)
	}

	ticker := time.NewTicker(p.pollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			if err := p.flush(ctx); err != nil && ctx.Err() == nil {
				p.logger.Error("outbox flush failed", "error", err)
			}
		}
	}
}

func (p *Publisher) flush(ctx context.Context) error {
	events, err := p.repo.ListPublishableOutboxEvents(ctx, p.batchSize)
	if err != nil {
		return err
	}

	for _, event := range events {
		if err := p.producer.PublishPayload(ctx, event.ID, event.Payload); err != nil {
			nextRetryAt := time.Now().UTC().Add(backoffDuration(event.Attempts + 1))
			if markErr := p.repo.MarkOutboxEventFailed(ctx, event.ID, nextRetryAt, err.Error()); markErr != nil {
				return markErr
			}
			p.logger.Error("outbox event publish failed",
				"event_id", event.ID,
				"event_type", event.EventType,
				"attempt", event.Attempts+1,
				"retry_at", nextRetryAt.Format(time.RFC3339),
				"error", err,
			)
			continue
		}

		if err := p.repo.MarkOutboxEventPublished(ctx, event.ID); err != nil {
			return err
		}

		p.logger.Info("outbox event published",
			"event_id", event.ID,
			"event_type", event.EventType,
		)
	}

	return nil
}

func backoffDuration(attempt int) time.Duration {
	if attempt <= 1 {
		return time.Second
	}

	if attempt > 6 {
		attempt = 6
	}

	return time.Second * time.Duration(1<<(attempt-1))
}
