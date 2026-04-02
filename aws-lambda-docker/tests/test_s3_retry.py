"""Tests for S3 client retry configuration."""

from __future__ import annotations

from s3_ops import _s3_client


class TestS3RetryConfig:
    def test_client_has_adaptive_retry(self) -> None:
        client = _s3_client()
        retry = client.meta.config.retries
        # botocore converts max_attempts=3 to total_max_attempts=4 (initial + 3 retries)
        assert retry["total_max_attempts"] == 4
        assert retry["mode"] == "adaptive"
