package outbox

import (
	"context"
	"log/slog"
	"time"

	"github.com/promex04/pody/server/identity-service/internal/notification"
	"github.com/promex04/pody/server/identity-service/internal/store"
)

// Publisher triển khai mẫu thiết kế Transactional Outbox Pattern.
// Nó định kỳ truy vấn từ bảng outbox trong cơ sở dữ liệu các event chưa được xuất bản
// và đẩy chúng lên hệ thống tin nhắn Kafka để đảm bảo tính nhất quán dữ liệu (eventual consistency).
type Publisher struct {
	repo         store.Repository       // Repository thao tác cơ sở dữ liệu
	producer     *notification.Producer // Producer đẩy tin nhắn lên Kafka
	logger       *slog.Logger           // Trình ghi log
	pollInterval time.Duration          // Chu kỳ thời gian giữa mỗi đợt quét DB
	batchSize    int                    // Số lượng event tối đa được quét và gửi trong mỗi đợt
}

// NewPublisher khởi tạo đối tượng Publisher mới với các tham số tương ứng.
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

// Run bắt đầu tiến trình chạy Publisher bất đồng bộ, thực hiện flush ngay lập tức khi khởi động, sau đó lặp lại định kỳ theo pollInterval.
func (p *Publisher) Run(ctx context.Context) error {
	if err := p.flush(ctx); err != nil && ctx.Err() == nil {
		p.logger.Error("outbox flush failed", "error", err)
	}

	ticker := time.NewTicker(p.pollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done(): // Dừng loop khi nhận tín hiệu kết thúc ứng dụng
			return nil
		case <-ticker.C: // Gọi flush định kỳ
			if err := p.flush(ctx); err != nil && ctx.Err() == nil {
				p.logger.Error("outbox flush failed", "error", err)
			}
		}
	}
}

// flush lấy danh sách các event publishable trong DB và xuất bản chúng lên Kafka.
// Nếu gửi thành công, cập nhật trạng thái đã xuất bản (published).
// Nếu gửi thất bại, tính toán thời gian thử lại kế tiếp (retry backoff) và đánh dấu lỗi.
func (p *Publisher) flush(ctx context.Context) error {
	events, err := p.repo.ListPublishableOutboxEvents(ctx, p.batchSize)
	if err != nil {
		return err
	}

	for _, event := range events {
		topic := notification.TopicFromEventType(event.EventType)
		// Thực hiện gửi payload event lên Kafka
		if err := p.producer.PublishPayload(ctx, topic, event.Key, event.Payload); err != nil {
			// Tính thời gian backoff dựa trên số lần đã thử
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

		// Đánh dấu đã gửi thành công trong DB
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

// backoffDuration tính toán khoảng thời gian delay trước khi thử lại dựa trên Exponential Backoff (2^attempt giây).
func backoffDuration(attempt int) time.Duration {
	if attempt <= 1 {
		return time.Second
	}

	if attempt > 6 {
		attempt = 6 // Giới hạn tối đa 6 lần (khoảng 32 giây) để tránh trì hoãn quá lâu
	}

	return time.Second * time.Duration(1<<(attempt-1))
}

