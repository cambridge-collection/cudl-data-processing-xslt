"""Tests for CloudWatch EMF metric emission in the handler."""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any
from unittest.mock import MagicMock, patch

from conftest import TEI_FILE

if TYPE_CHECKING:
    import pytest


def _make_sqs_record(
    event_name: str = "ObjectCreated:Put",
    bucket: str = "test-source-bucket",
    key: str = TEI_FILE,
    message_id: str = "msg-001",
) -> dict[str, Any]:
    body = {
        "Records": [
            {
                "eventName": event_name,
                "s3": {"bucket": {"name": bucket}, "object": {"key": key}},
            }
        ]
    }
    return {"messageId": message_id, "body": json.dumps(body)}


def _wrap_records(*records: dict[str, Any]) -> dict[str, Any]:
    return {"Records": list(records)}


class TestEMFEmission:
    """EMF metrics are emitted on error when EMIT_EMF_METRICS=true."""

    @patch("handler._handle_created", side_effect=Exception("boom"))
    @patch("handler.setup_workspace")
    def test_emf_emitted_on_transient_error(
        self,
        _setup: MagicMock,
        _created: MagicMock,
        env_config: None,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setenv("EMIT_EMF_METRICS", "true")

        from handler import handler

        result = handler(_wrap_records(_make_sqs_record()), None)

        assert result["batchItemFailures"] == [{"itemIdentifier": "msg-001"}]

        stdout = capsys.readouterr().out
        emf_lines = [
            json.loads(line)
            for line in stdout.splitlines()
            if line.strip().startswith("{") and "_aws" in line
        ]
        assert len(emf_lines) == 1
        emf = emf_lines[0]
        assert emf["_aws"]["CloudWatchMetrics"][0]["Namespace"] == "CUDL/Processing"
        assert emf["EventType"] == "ObjectCreated"
        assert emf["ErrorType"] == "transient"
        assert emf["ErrorCount"] == 1

    @patch("handler._handle_created", side_effect=Exception("boom"))
    @patch("handler.setup_workspace")
    def test_emf_suppressed_when_disabled(
        self,
        _setup: MagicMock,
        _created: MagicMock,
        env_config: None,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setenv("EMIT_EMF_METRICS", "false")

        from handler import handler

        handler(_wrap_records(_make_sqs_record()), None)

        stdout = capsys.readouterr().out
        emf_lines = [line for line in stdout.splitlines() if "_aws" in line]
        assert emf_lines == []

    @patch("handler._handle_created", side_effect=Exception("boom"))
    @patch("handler.setup_workspace")
    def test_emf_disabled_by_default(
        self,
        _setup: MagicMock,
        _created: MagicMock,
        env_config: None,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.delenv("EMIT_EMF_METRICS", raising=False)

        from handler import handler

        handler(_wrap_records(_make_sqs_record()), None)

        stdout = capsys.readouterr().out
        emf_lines = [line for line in stdout.splitlines() if "_aws" in line]
        assert emf_lines == []

    @patch("handler._handle_created")
    @patch("handler.setup_workspace")
    def test_emf_permanent_error_classification(
        self,
        _setup: MagicMock,
        mock_created: MagicMock,
        env_config: None,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        from exceptions import PermanentError

        monkeypatch.setenv("EMIT_EMF_METRICS", "true")
        mock_created.side_effect = PermanentError("bad XML")

        from handler import handler

        handler(_wrap_records(_make_sqs_record()), None)

        stdout = capsys.readouterr().out
        emf_lines = [
            json.loads(line)
            for line in stdout.splitlines()
            if line.strip().startswith("{") and "_aws" in line
        ]
        assert len(emf_lines) == 1
        assert emf_lines[0]["ErrorType"] == "permanent"
