package store

import (
	"context"
	"database/sql"
	"errors"
	"time"
)

var ErrNotFound = errors.New("not found")

type ProcessedEventStore interface {
	HasProcessedEvent(ctx context.Context, eventID string) (bool, error)
	MarkProcessedEvent(ctx context.Context, eventID, sourceService, eventType string) error
	DeleteProcessedEventsBefore(ctx context.Context, before time.Time, limit int) (int64, error)
}

type PostgresStore struct {
	db *sql.DB
}

func NewPostgresStore(db *sql.DB) ProcessedEventStore {
	return &PostgresStore{db: db}
}

func (s *PostgresStore) HasProcessedEvent(ctx context.Context, eventID string) (bool, error) {
	var exists bool
	err := s.db.QueryRowContext(ctx, `
		SELECT EXISTS (
			SELECT 1
			FROM inbox_processed_events
			WHERE event_id = $1
		)
	`, eventID).Scan(&exists)
	return exists, err
}

func (s *PostgresStore) MarkProcessedEvent(ctx context.Context, eventID, sourceService, eventType string) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO inbox_processed_events (event_id, source_service, event_type)
		VALUES ($1, $2, $3)
		ON CONFLICT (event_id) DO NOTHING
	`, eventID, sourceService, eventType)
	return err
}

func (s *PostgresStore) DeleteProcessedEventsBefore(ctx context.Context, before time.Time, limit int) (int64, error) {
	if limit <= 0 {
		limit = 500
	}

	result, err := s.db.ExecContext(ctx, `
		DELETE FROM inbox_processed_events
		WHERE id IN (
			SELECT id
			FROM inbox_processed_events
			WHERE processed_at < $1
			ORDER BY processed_at ASC
			LIMIT $2
		)
	`, before, limit)
	if err != nil {
		return 0, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return 0, err
	}

	return rowsAffected, nil
}
