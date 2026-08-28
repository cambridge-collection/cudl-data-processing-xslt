"""Tests for handler.py — SQS event parsing, routing, partial batch failures, and timeout."""

from __future__ import annotations

import json
from typing import Any
from unittest.mock import MagicMock, patch

import pytest

from conftest import TEI_FILE
from exceptions import PermanentError, TransientError
from handler import _parse_record


def _make_context(remaining_ms: int) -> MagicMock:
    """Build a mock Lambda context with a fixed remaining time."""
    ctx = MagicMock()
    ctx.get_remaining_time_in_millis.return_value = remaining_ms
    return ctx


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


class TestRequestIdCorrelation:
    """The Lambda request id is logged so a native crash can be traced to its record."""

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_request_id_in_log_context_during_processing(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
    ) -> None:
        from handler import handler
        from logging_config import log_context

        seen: list[dict[str, object]] = []
        mock_created.side_effect = lambda *a, **kw: seen.append(dict(log_context.get() or {}))

        ctx = _make_context(60_000)
        ctx.aws_request_id = "req-abc-123"

        handler(_wrap_records(_make_sqs_record(message_id="msg-a")), ctx)

        assert len(seen) == 1
        assert seen[0]["aws_request_id"] == "req-abc-123"
        assert seen[0]["message_id"] == "msg-a"
        assert seen[0]["tei_file"] == TEI_FILE

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_missing_context_does_not_break_processing(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
    ) -> None:
        from handler import handler

        result = handler(_wrap_records(_make_sqs_record(message_id="msg-a")), None)

        assert result == {"batchItemFailures": []}
        mock_created.assert_called_once()


class TestSetupFailure:
    """Invocation-level setup failures still report every record as a failure."""

    @patch("handler.setup_workspace")
    def test_workspace_setup_failure_fails_whole_batch(
        self,
        mock_setup: MagicMock,
        env_config: None,
    ) -> None:
        from handler import handler

        mock_setup.side_effect = OSError("read-only filesystem")

        result = handler(
            _wrap_records(
                _make_sqs_record(message_id="msg-a"),
                _make_sqs_record(message_id="msg-b"),
            ),
            None,
        )

        assert result == {
            "batchItemFailures": [
                {"itemIdentifier": "msg-a"},
                {"itemIdentifier": "msg-b"},
            ]
        }

    @patch("handler.setup_workspace")
    def test_invalid_config_fails_whole_batch(
        self,
        mock_setup: MagicMock,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        from handler import handler

        monkeypatch.delenv("AWS_OUTPUT_BUCKET", raising=False)

        result = handler(_wrap_records(_make_sqs_record(message_id="msg-a")), None)

        assert result == {"batchItemFailures": [{"itemIdentifier": "msg-a"}]}
        mock_setup.assert_not_called()


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


class TestTimeoutSafeProcessing:
    """Verify early exit when Lambda remaining time drops below margin."""

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_early_exit_returns_unprocessed_as_failures(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
    ) -> None:
        """When time runs low after 2 records, remaining 3 are returned as failures."""
        from handler import handler

        records = [_make_sqs_record(message_id=f"msg-{i}") for i in range(5)]
        event = _wrap_records(*records)

        # Enough time for first 2 records, then drop below margin
        ctx = MagicMock()
        ctx.get_remaining_time_in_millis.side_effect = [30000, 20000, 3000]

        result = handler(event, ctx)

        assert mock_created.call_count == 2
        failed_ids = [f["itemIdentifier"] for f in result["batchItemFailures"]]
        assert failed_ids == ["msg-2", "msg-3", "msg-4"]

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_no_early_exit_when_time_sufficient(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
    ) -> None:
        """All records processed when plenty of time remains."""
        from handler import handler

        records = [_make_sqs_record(message_id=f"msg-{i}") for i in range(3)]
        event = _wrap_records(*records)

        ctx = _make_context(60000)

        result = handler(event, ctx)

        assert mock_created.call_count == 3
        assert result == {"batchItemFailures": []}

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_succeeded_records_not_in_failures(
        self,
        mock_setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
    ) -> None:
        """Records that already succeeded before timeout are not in failures."""
        from handler import handler

        records = [_make_sqs_record(message_id=f"msg-{i}") for i in range(4)]
        event = _wrap_records(*records)

        # Process 1 record successfully, then timeout on 2nd check
        ctx = MagicMock()
        ctx.get_remaining_time_in_millis.side_effect = [30000, 2000]

        result = handler(event, ctx)

        assert mock_created.call_count == 1
        failed_ids = [f["itemIdentifier"] for f in result["batchItemFailures"]]
        # msg-0 succeeded — only msg-1, msg-2, msg-3 are failures
        assert "msg-0" not in failed_ids
        assert failed_ids == ["msg-1", "msg-2", "msg-3"]
