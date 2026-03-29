from __future__ import annotations

__all__ = [
    "ArticleSearchController",
    "ArticleEventController",
    "KafkaArticleConsumerController",
    "SystemController",
]


def __getattr__(name: str):
    if name == "ArticleSearchController":
        from .article_search_controller import ArticleSearchController

        return ArticleSearchController
    if name == "ArticleEventController":
        from .article_event_controller import ArticleEventController

        return ArticleEventController
    if name == "KafkaArticleConsumerController":
        from .kafka_article_consumer_controller import KafkaArticleConsumerController

        return KafkaArticleConsumerController
    if name == "SystemController":
        from .system_controller import SystemController

        return SystemController
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
