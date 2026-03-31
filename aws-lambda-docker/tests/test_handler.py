"""Tests for handler.py — SQS event parsing and routing."""

from __future__ import annotations

import json
from typing import Any
from unittest.mock import MagicMock, patch

import pytest

from conftest import TEI_FILE


class TestSQSEventParsing:
    """The nested SQS→S3 JSON structure is the most fragile part."""

    def test_parses_real_fixture(self, sqs_event: dict[str, Any]) -> None:
        """Verify parsing matches the real event fixture."""
        record = sqs_event["Records"][0]
        body = json.loads(record["body"])
        s3_event = body["Records"][0]

        assert s3_event["eventName"] == "ObjectCreated:Put"
        assert s3_event["s3"]["bucket"]["name"] == "mjh39-sandbox-cudl-data-source"
        assert s3_event["s3"]["object"]["key"] == TEI_FILE

    def test_body_is_string_not_dict(self, sqs_event: dict[str, Any]) -> None:
        """Body must be JSON string, not already-parsed dict."""
        body_raw = sqs_event["Records"][0]["body"]
        assert isinstance(body_raw, str)

    def test_malformed_body_raises(self, sqs_event: dict[str, Any]) -> None:
        """Non-JSON body should raise during parsing."""
        sqs_event["Records"][0]["body"] = "not-json"
        with pytest.raises(json.JSONDecodeError):
            json.loads(sqs_event["Records"][0]["body"])

    def test_missing_s3_records_raises(self, sqs_event: dict[str, Any]) -> None:
        """Body with no Records key should raise."""
        sqs_event["Records"][0]["body"] = json.dumps({"noRecords": []})
        body = json.loads(sqs_event["Records"][0]["body"])
        with pytest.raises(KeyError):
            _ = body["Records"][0]


class TestHandlerRouting:
    """Verify handler routes to correct _handle_created / _handle_removed."""

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_routes_object_created(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        sqs_event: dict[str, Any],
        env_config: None,
    ) -> None:
        from handler import handler

        result = handler(sqs_event, None)

        mock_setup.assert_called_once()
        mock_created.assert_called_once()
        args = mock_created.call_args
        assert args[0][1] == "mjh39-sandbox-cudl-data-source"  # s3_bucket
        assert args[0][2] == TEI_FILE  # tei_file
        assert result["statusCode"] == 200

    @patch("handler._handle_removed")
    @patch("handler.setup_workspace")
    def test_routes_object_removed(
        self,
        mock_setup: MagicMock,
        mock_removed: MagicMock,
        sqs_event: dict[str, Any],
        env_config: None,
    ) -> None:
        from handler import handler

        # Modify event to ObjectRemoved
        body = json.loads(sqs_event["Records"][0]["body"])
        body["Records"][0]["eventName"] = "ObjectRemoved:Delete"
        sqs_event["Records"][0]["body"] = json.dumps(body)

        result = handler(sqs_event, None)

        mock_removed.assert_called_once()
        assert result["statusCode"] == 200

    @patch("handler.setup_workspace")
    def test_unsupported_event_raises(
        self,
        mock_setup: MagicMock,
        sqs_event: dict[str, Any],
        env_config: None,
    ) -> None:
        from handler import handler

        body = json.loads(sqs_event["Records"][0]["body"])
        body["Records"][0]["eventName"] = "SomethingElse"
        sqs_event["Records"][0]["body"] = json.dumps(body)

        with pytest.raises(ValueError, match="Unsupported event"):
            handler(sqs_event, None)
