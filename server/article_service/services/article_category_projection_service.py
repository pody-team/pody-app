from __future__ import annotations

import logging

from category_sync_event import ArticleCategoryMatchesGeneratedEvent


class ArticleCategoryProjectionService:
    def __init__(self, repository, logger: logging.Logger):
        self._repository = repository
        self._logger = logger

    async def apply_event(self, event: ArticleCategoryMatchesGeneratedEvent) -> str:
        if await self._repository.has_processed_event(event_id=event.event_id):
            self._logger.info(
                "Article-category sync event skipped as duplicate | event_id=%s article_id=%s",
                event.event_id,
                event.article_id,
            )
            return "duplicate"

        if not await self._repository.article_exists(article_id=event.article_id):
            await self._repository.mark_event_processed(
                event_id=event.event_id,
                source_service=event.source_service,
                event_type=event.event_type,
            )
            self._logger.info(
                "Article-category sync skipped because article was not found | event_id=%s article_id=%s",
                event.event_id,
                event.article_id,
            )
            return "missing-article"

        valid_category_ids = await self._repository.list_active_category_ids(
            category_ids=[str(match.category_id) for match in event.matches]
        )
        seen_category_ids: set[str] = set()
        projected_matches = []
        for match in event.matches:
            category_id = str(match.category_id)
            if category_id not in valid_category_ids or category_id in seen_category_ids:
                continue
            seen_category_ids.add(category_id)
            projected_matches.append(
                {
                    "category_id": category_id,
                    "match_rank": match.rank,
                    "score": match.score,
                    "is_primary": match.rank == 1,
                }
            )

        await self._repository.replace_semantic_category_links(
            article_id=event.article_id,
            matches=projected_matches,
            model_name=event.model_name,
            embedding_version=event.embedding_version,
            assigned_at=event.occurred_at,
        )
        await self._repository.mark_event_processed(
            event_id=event.event_id,
            source_service=event.source_service,
            event_type=event.event_type,
        )

        self._logger.info(
            "Article-category sync applied | event_id=%s article_id=%s match_count=%s",
            event.event_id,
            event.article_id,
            len(projected_matches),
        )
        return "applied"
