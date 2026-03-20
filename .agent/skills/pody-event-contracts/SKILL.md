---
name: pody-event-contracts
description: Maintain async event contracts in the Pody repo. Use when adding or changing Kafka events, outbox payloads, retry and DLQ behavior, idempotency keys, processed-event tracking, delivery logs, or producer and consumer tests between services such as identity-service and notification-service.
---

# Pody Event Contracts

Keep event names, payloads, outbox behavior, retry rules, and consumer side effects aligned across Pody services.

## Workflow

1. Start from the full event lifecycle.
   Read the producer, the place where the event is written into the outbox, the publisher worker, and the consumer that handles the topic. Do not change just one side of the contract.

2. Reuse the current event envelope.
   Pody events already carry stable metadata such as `event_id`, `idempotency_key`, `event_type`, and `occurred_at`.
   Keep the business payload fields explicit and flat unless there is a strong reason not to.

3. Prefer transactional outbox for domain-triggered async work.
   When an event depends on a database write, persist the domain change and the outbox row in the same transaction.
   Use the outbox publisher to fan the payload out to Kafka instead of publishing directly from request-time code.

4. Keep event naming and versioning predictable.
   Use topic-style names such as `identity.email.verification.requested`.
   Append the schema version in `event_type`, for example `.v1`.
   Keep Kafka topic naming, retry topics, and DLQ topics derived from the base event family.

5. Preserve idempotency and failure handling.
   Producers should populate `idempotency_key`.
   Consumers should dedupe by `event_id`, retry transient failures with attempt headers, and move permanently failing or invalid messages to DLQ with the error attached.

6. Test the contract at every boundary.
   Add producer tests, outbox persistence tests, consumer success tests, duplicate-skip tests, retry tests, and DLQ tests when the contract changes.

## Checklists

### Event Shape

- Keep `event_id`, `idempotency_key`, `event_type`, and `occurred_at`.
- Keep business fields named after the actual domain data.
- Bump version only when the payload contract truly changes.

### Outbox And Publishing

- Write the outbox row in the same transaction as the business state change.
- Keep `aggregate_type`, `aggregate_id`, `event_type`, `payload_version`, and JSON payload populated.
- Publish using the outbox worker for transactional flows.

### Consumer Reliability

- Reject invalid JSON into DLQ.
- Skip duplicates by checking processed events.
- On temporary delivery failure, publish to retry with incremented attempt headers.
- On max-attempt failure, publish to DLQ with the last error.
- Record delivery logs for both success and failure.

## Repo Notes

Read [references/pody-event-contracts-reference.md](references/pody-event-contracts-reference.md) for the current event types, topic names, retry headers, file map, and verification checklist.
