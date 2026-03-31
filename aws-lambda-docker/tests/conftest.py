"""Shared test fixtures."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

TEST_DIR = Path(__file__).parent.parent.parent / "test"
TEI_FILE = "items/data/tei/MS-ADD-03975/MS-ADD-03975.xml"
BUCKET = "test-source-bucket"
OUTPUT_BUCKET = "test-output-bucket"


@pytest.fixture()
def sqs_event() -> dict[str, Any]:
    """Real SQS event from test fixture."""
    raw = (TEST_DIR / "sns-tei-source-change.json").read_text()
    return json.loads(raw)


@pytest.fixture()
def s3_event_body(sqs_event: dict[str, Any]) -> dict[str, Any]:
    """Parsed inner S3 event (the body JSON inside the SQS record)."""
    return json.loads(sqs_event["Records"][0]["body"])


@pytest.fixture()
def env_config(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set minimum config env vars for tests."""
    monkeypatch.setenv("AWS_OUTPUT_BUCKET", OUTPUT_BUCKET)
    monkeypatch.setenv("SEARCH_HOST", "localhost")
    monkeypatch.setenv("SEARCH_PORT", "8983")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "eu-west-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
