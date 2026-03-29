from __future__ import annotations

__all__ = [
    "ArticleSearchController",
    "ArticleEventController",
    "CategoryEventController",
    "KafkaArticleConsumerController",
    "KafkaCategoryConsumerController",
    "SystemController",
]


def __getattr__(name: str):
    if name == "ArticleSearchController":
        from .article_search_controller import ArticleSearchController

        return ArticleSearchController
    if name == "ArticleEventController":
        from .article_event_controller import ArticleEventController

        return ArticleEventController
    if name == "CategoryEventController":
        from .category_event_controller import CategoryEventController

        return CategoryEventController
    if name == "KafkaArticleConsumerController":
        from .kafka_article_consumer_controller import KafkaArticleConsumerController

        return KafkaArticleConsumerController
    if name == "KafkaCategoryConsumerController":
        from .kafka_category_consumer_controller import KafkaCategoryConsumerController

        return KafkaCategoryConsumerController
    if name == "SystemController":
        from .system_controller import SystemController

        return SystemController
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
