package cleanup

import (
	"context"
	"log/slog"
	"time"

	"github.com/promex04/pody/server/notification-service/internal/store"
)

type ProcessedEventsWorker struct {
	store     store.ProcessedEventStore
	logger    *slog.Logger
	interval  time.Duration
	retention time.Duration
	batchSize int
}

func NewProcessedEventsWorker(store store.ProcessedEventStore, logger *slog.Logger, interval, retention time.Duration, batchSize int) *ProcessedEventsWorker {
	if interval <= 0 {
		interval = time.Hour
	}

	if retention <= 0 {
		retention = 7 * 24 * time.Hour
	}

	if batchSize <= 0 {
		batchSize = 500
	}

	return &ProcessedEventsWorker{
		store:     store,
		logger:    logger,
		interval:  interval,
		retention: retention,
		batchSize: batchSize,
	}
}

func (w *ProcessedEventsWorker) Run(ctx context.Context) error {
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			if err := w.cleanup(ctx); err != nil && ctx.Err() == nil {
				w.logger.Error("processed events cleanup failed", "error", err)
			}
		}
	}
}

func (w *ProcessedEventsWorker) cleanup(ctx context.Context) error {
	before := time.Now().UTC().Add(-w.retention)
	deleted, err := w.store.DeleteProcessedEventsBefore(ctx, before, w.batchSize)
	if err != nil {
		return err
	}

	if deleted > 0 {
		w.logger.Info("processed events cleanup completed", "deleted", deleted, "before", before.Format(time.RFC3339))
	}

	return nil
}
