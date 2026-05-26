package outbox

import (
	"context"
	"log/slog"
	"time"

	"github.com/promex04/pody/server/identity-service/internal/store"
)

// CleanupWorker quản lý tiến trình dọn dẹp (cleanup) các event outbox cũ đã được xuất bản thành công.
type CleanupWorker struct {
	repo      store.Repository // Repository tương tác DB PostgreSQL
	logger    *slog.Logger     // Trình ghi log
	interval  time.Duration    // Chu kỳ thời gian chạy tác vụ dọn dẹp định kỳ
	retention time.Duration    // Thời gian lưu trữ tối đa của một event (những event cũ hơn thời gian này sẽ bị xóa)
	batchSize int              // Số lượng dòng tối đa cần xóa trong một đợt (batch) để tránh block DB
}

// NewCleanupWorker khởi tạo CleanupWorker mới với các tham số chu kỳ chạy, thời gian lưu trữ, và batch size.
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

// Run bắt đầu vòng lặp ticker bất đồng bộ định kỳ gọi hàm dọn dẹp các event outbox cũ.
func (w *CleanupWorker) Run(ctx context.Context) error {
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done(): // Dừng loop khi context bị canceled
			return nil
		case <-ticker.C: // Kích hoạt dọn dẹp định kỳ
			if err := w.cleanup(ctx); err != nil && ctx.Err() == nil {
				w.logger.Error("outbox cleanup failed", "error", err)
			}
		}
	}
}

// cleanup tính toán mốc thời gian cũ tương ứng với cấu hình retention và thực thi câu lệnh SQL xóa các bản ghi outbox đã gửi thành công trước mốc thời gian đó.
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

