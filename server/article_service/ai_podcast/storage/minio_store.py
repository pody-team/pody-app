from __future__ import annotations

import io
import json

from ai_podcast.config import AIPodcastSettings

try:
    from minio import Minio
except ImportError:  # pragma: no cover - optional dependency in tests
    Minio = None


class MinIOPodcastStore:
    def __init__(self, settings: AIPodcastSettings) -> None:
        self._bucket = settings.article_podcast_bucket
        self._public_base_url = (settings.minio_public_base_url or "").rstrip("/")
        self._enabled = bool(
            Minio is not None
            and settings.minio_endpoint
            and settings.minio_access_key
            and settings.minio_secret_key
            and settings.minio_public_base_url
        )
        self._client = None
        if self._enabled:
            self._client = Minio(
                settings.minio_endpoint,
                access_key=settings.minio_access_key,
                secret_key=settings.minio_secret_key,
                secure=settings.minio_use_ssl,
                region=settings.minio_region,
            )

    @property
    def enabled(self) -> bool:
        return self._enabled and self._client is not None

    @property
    def bucket_name(self) -> str:
        return self._bucket

    def ensure_bucket(self) -> None:
        if not self.enabled:
            return
        if not self._client.bucket_exists(self._bucket):
            self._client.make_bucket(self._bucket)
        policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"AWS": ["*"]},
                    "Action": ["s3:GetBucketLocation", "s3:ListBucket"],
                    "Resource": [f"arn:aws:s3:::{self._bucket}"],
                },
                {
                    "Effect": "Allow",
                    "Principal": {"AWS": ["*"]},
                    "Action": ["s3:GetObject"],
                    "Resource": [f"arn:aws:s3:::{self._bucket}/*"],
                },
            ],
        }
        self._client.set_bucket_policy(self._bucket, json.dumps(policy))

    def upload_audio(self, *, object_key: str, body: bytes, content_type: str) -> tuple[str, str]:
        if not self.enabled:
            raise RuntimeError("article podcast minio storage is not configured")
        self._client.put_object(
            self._bucket,
            object_key,
            io.BytesIO(body),
            length=len(body),
            content_type=content_type,
        )
        return f"{self._public_base_url}/{self._bucket}/{object_key}", object_key

    def upload_transcript(self, *, object_key: str, transcript_json: str) -> tuple[str, str]:
        payload = transcript_json.encode("utf-8")
        return self.upload_audio(
            object_key=object_key,
            body=payload,
            content_type="application/json; charset=utf-8",
        )
