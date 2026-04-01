"""Tests for handler.py — SQS event parsing, routing, and partial batch failures."""

from __future__ import annotations

import json
from typing import Any
from unittest.mock import MagicMock, patch

import pytest

from conftest import TEI_FILE
from exceptions import PermanentError, TransientError
from handler import _parse_record


def _make_sqs_record(
    event_name: str = "ObjectCreated:Put",
    bucket: str = "mjh39-sandbox-cudl-data-source",
    key: str = TEI_FILE,
    message_id: str = "msg-001",
) -> dict[str, Any]:
    """Build a minimal SQS record wrapping an S3 event."""
    body = {
        "Records": [
            {
                "eventName": event_name,
                "s3": {
                    "bucket": {"name": bucket},
                    "object": {"key": key},
                },
            }
        ]
    }
    return {"messageId": message_id, "body": json.dumps(body)}


def _wrap_records(*records: dict[str, Any]) -> dict[str, Any]:
    """Wrap SQS records into a Lambda event."""
    return {"Records": list(records)}


class TestRecordParsing:
    """_parse_record extracts S3 event fields from a single SQS record."""

    def test_parses_real_fixture(self, sqs_event: dict[str, Any]) -> None:
        record = sqs_event["Records"][0]
        event_name, bucket, key = _parse_record(record)

        assert event_name == "ObjectCreated:Put"
        assert bucket == "mjh39-sandbox-cudl-data-source"
        assert key == TEI_FILE

    def test_malformed_body_raises_permanent(self, sqs_event: dict[str, Any]) -> None:
        record = sqs_event["Records"][0]
        record["body"] = "not-json"
        with pytest.raises(PermanentError, match="Cannot parse SQS record"):
            _parse_record(record)

    def test_missing_s3_records_raises_permanent(self, sqs_event: dict[str, Any]) -> None:
        record = sqs_event["Records"][0]
        record["body"] = json.dumps({"noRecords": []})
        with pytest.raises(PermanentError, match="Cannot parse SQS record"):
            _parse_record(record)


class TestHandlerRouting:
    """Verify handler routes to correct _handle_created / _handle_removed."""

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_routes_object_created(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
    ) -> None:
        from handler import handler

        event = _wrap_records(_make_sqs_record())
        result = handler(event, None)

        mock_setup.assert_called_once()
        mock_created.assert_called_once()
        args = mock_created.call_args
        assert args[0][1] == "mjh39-sandbox-cudl-data-source"
        assert args[0][2] == TEI_FILE
        assert result == {"batchItemFailures": []}

    @patch("handler._handle_removed")
    @patch("handler.setup_workspace")
    def test_routes_object_removed(
        self,
        mock_setup: MagicMock,
        mock_removed: MagicMock,
        env_config: None,
    ) -> None:
        from handler import handler

        record = _make_sqs_record(event_name="ObjectRemoved:Delete")
        result = handler(_wrap_records(record), None)

        mock_removed.assert_called_once()
        assert result == {"batchItemFailures": []}

    @patch("handler.setup_workspace")
    def test_unsupported_event_is_permanent_failure(
        self,
        mock_setup: MagicMock,
        env_config: None,
    ) -> None:
        from handler import handler

        record = _make_sqs_record(event_name="SomethingElse", message_id="bad-event")
        result = handler(_wrap_records(record), None)

        assert result == {"batchItemFailures": [{"itemIdentifier": "bad-event"}]}


class TestPartialBatchFailures:
    """Verify per-record failure isolation and batchItemFailures reporting."""

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_mixed_batch_one_success_one_transient(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
    ) -> None:
        """Only the failed record's messageId appears in batchItemFailures."""
        from handler import handler

        good = _make_sqs_record(message_id="msg-ok")
        bad = _make_sqs_record(message_id="msg-fail")

        mock_created.side_effect = [None, TransientError("S3 timeout")]

        result = handler(_wrap_records(good, bad), None)

        assert mock_created.call_count == 2
        assert result == {"batchItemFailures": [{"itemIdentifier": "msg-fail"}]}

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_permanent_error_included_in_failures(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
    ) -> None:
        """Permanent errors are reported so they exhaust retries and reach DLQ."""
        from handler import handler

        record = _make_sqs_record(message_id="msg-perm")
        mock_created.side_effect = PermanentError("Malformed XML")

        result = handler(_wrap_records(record), None)

        assert result == {"batchItemFailures": [{"itemIdentifier": "msg-perm"}]}

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_all_records_processed(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
    ) -> None:
        """Every record in the batch is processed, not just the first."""
        from handler import handler

        records = [_make_sqs_record(message_id=f"msg-{i}") for i in range(5)]
        event = _wrap_records(*records)

        result = handler(event, None)

        assert mock_created.call_count == 5
        assert result == {"batchItemFailures": []}

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_parse_failure_does_not_block_remaining_records(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
    ) -> None:
        """A malformed record doesn't prevent processing subsequent records."""
        from handler import handler

        bad = {"messageId": "msg-bad", "body": "not-json"}
        good = _make_sqs_record(message_id="msg-good")

        result = handler(_wrap_records(bad, good), None)

        mock_created.assert_called_once()  # good record still processed
        assert result == {"batchItemFailures": [{"itemIdentifier": "msg-bad"}]}
