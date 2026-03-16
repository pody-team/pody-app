package outbox

import (
	"context"
	"log/slog"
	"time"

	"github.com/promex04/pody/server/identity-service/internal/store"
)

type CleanupWorker struct {
	repo      store.Repository
	logger    *slog.Logger
	interval  time.Duration
	retention time.Duration
	batchSize int
}

func NewCleanupWorker(repo store.Repository, logger *slog.Logger, interval, retention time.Duration, batchSize int) *CleanupWorker {
	if interval <= 0 {
		interval = time.Hour
	}

	if retention <= 0 {
		retention = 7 * 24 * time.Hour
	}

	if batchSize <= 0 {
		batchSize = 200
	}

	return &CleanupWorker{
		repo:      repo,
		logger:    logger,
		interval:  interval,
		retention: retention,
		batchSize: batchSize,
	}
}

func (w *CleanupWorker) Run(ctx context.Context) error {
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			if err := w.cleanup(ctx); err != nil && ctx.Err() == nil {
				w.logger.Error("outbox cleanup failed", "error", err)
			}
		}
	}
}

func (w *CleanupWorker) cleanup(ctx context.Context) error {
	before := time.Now().UTC().Add(-w.retention)
	deleted, err := w.repo.DeletePublishedOutboxEventsBefore(ctx, before, w.batchSize)
	if err != nil {
		return err
	}

	if deleted > 0 {
		w.logger.Info("outbox cleanup completed", "deleted", deleted, "before", before.Format(time.RFC3339))
	}

	return nil
}
