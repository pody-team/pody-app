# Pody Event Contracts Reference

## Files To Read First

Producer and event definitions:

- `server/identity-service/internal/notification/producer.go`
- `server/identity-service/internal/notification/producer_test.go`

Outbox persistence and publishing:

- `server/identity-service/internal/auth/service.go`
- `server/identity-service/internal/store/postgres.go`
- `server/identity-service/internal/outbox/publisher.go`
- `server/identity-service/internal/outbox/cleanup.go`

Consumers and processed-event tracking:

- `server/notification-service/internal/consumer/verification.go`
- `server/notification-service/internal/consumer/password_reset.go`
- `server/notification-service/internal/consumer/verification_test.go`
- `server/notification-service/internal/store/postgres.go`
- `server/notification-service/internal/cleanup/processed_events.go`
- `server/notification-service/internal/config/config.go`

## Current Event Families

Verification:

- Base topic: `identity.email.verification.requested`
- Retry topic: `identity.email.verification.requested.retry`
- DLQ topic: `identity.email.verification.requested.dlq`
- Event type: `identity.email.verification.requested.v1`

Password reset:

- Base topic: `identity.password.reset.requested`
- Retry topic: `identity.password.reset.requested.retry`
- DLQ topic: `identity.password.reset.requested.dlq`
- Event type: `identity.password.reset.requested.v1`

Keep new event families in this same pattern.

## Event Envelope Conventions

Current verification and password reset events include:

- `event_id`
- `idempotency_key`
- `event_type`
- `occurred_at`
- domain fields such as `user_id`, `to_email`, `to_display_name`, `verification_url`, `reset_otp`, `expires_at`

Producer rules:

- Generate `event_id` if missing.
- Default `idempotency_key` to `event_id` if missing.
- Set `event_type` to `<topic>.v1`.
- Use `TopicFromEventType(event_type)` to map back to the Kafka topic.
- Publish Kafka message key as the idempotency key.

## Outbox Conventions

Current transactional pattern in `identity-service`:

1. Create or update the domain state in the database.
2. Insert or rotate the token record.
3. Insert one `outbox_events` row in the same transaction.

Current outbox row fields:

- `aggregate_type`
- `aggregate_id`
- `event_type`
- `payload_version`
- `payload`

Current values used by identity flows:

- `aggregate_type: "user"`
- `aggregate_id: <user id>`
- `payload_version: 1`

Publisher behavior:

- Fetch publishable rows where status is `pending` or `failed` and `available_at <= now()`
- Publish the stored JSON payload to Kafka
- Mark success as `published`
- On failure, increment attempts and set `available_at` using exponential backoff

Current outbox backoff:

- attempt 1: `1s`
- attempt 2: `2s`
- attempt 3: `4s`
- attempt 4: `8s`
- attempt 5: `16s`
- attempt 6+: capped at `32s`

Cleanup:

- `identity-service` deletes old published outbox rows by retention window

## Consumer Reliability Conventions

Current verification and password-reset consumers:

- Consume both base topic and retry topic in the same consumer group
- Parse JSON payload into a typed event struct
- Default missing `idempotency_key` to `event_id`
- Check `HasProcessedEvent(event_id)` before sending
- On success:
  - send email
  - `MarkProcessedEvent(event_id, sourceService, eventType)`
  - create a `"sent"` delivery log
  - commit Kafka message
- On temporary failure:
  - create a `"failed"` delivery log
  - publish to retry topic
  - increment attempt header
  - commit Kafka message
- On max-attempt failure:
  - create a `"failed"` delivery log
  - publish to DLQ
  - attach the last error header
  - commit Kafka message
- On invalid JSON:
  - publish directly to DLQ
  - commit Kafka message

Current Kafka headers used for retry and DLQ:

- `x-attempt`
- `x-idempotency-key`
- `x-last-error`

Current consumer defaults:

- verification max attempts: `5`
- password reset max attempts: `5`

Processed-event cleanup:

- `notification-service` periodically deletes old rows from `inbox_processed_events`

## Design Guidance For New Events

- Use Kafka events for async side effects that should survive transient failures.
- Prefer outbox over direct publish when the event must reflect committed database state.
- Keep payloads explicit; avoid embedding large unrelated objects.
- Add a new event family instead of overloading verification or password reset semantics.
- If a consumer derives behavior from wiring rather than payload, document that in code and tests.
- Avoid duplicating the same business trigger across direct internal HTTP and Kafka unless both paths are intentionally supported.

## Minimum Test Set

Producer side:

- marshals the expected event metadata
- publishes to the correct topic
- uses idempotency key as Kafka key
- propagates writer failure

Outbox side:

- service test proves one outbox event is created for the business action
- payload in outbox can be unmarshaled into the expected event struct

Consumer side:

- success path sends the message and marks the event processed
- duplicate path skips sending
- temporary failure sends to retry with incremented attempt
- exceeded-attempt failure sends to DLQ
- invalid JSON goes to DLQ

## Useful Checks

```bash
rg -n 'event_id|idempotency_key|event_type|TopicFromEventType|Create.*Outbox|retry|dlq' server
go test ./...
```

Run targeted Go tests from:

- `server/identity-service`
- `server/notification-service`
