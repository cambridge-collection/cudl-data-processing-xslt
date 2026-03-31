"""Tests for structured JSON logging."""

from __future__ import annotations

import json
import logging

import pytest

from logging_config import JSONFormatter, configure_logging


@pytest.fixture(autouse=True)
def _reset_root_logger() -> None:
    """Reset root logger after each test."""
    root = logging.getLogger()
    original_handlers = root.handlers[:]
    original_level = root.level
    yield  # type: ignore[misc]
    root.handlers = original_handlers
    root.level = original_level


class TestJSONFormatter:
    def test_basic_fields(self) -> None:
        formatter = JSONFormatter()
        record = logging.LogRecord(
            name="test.module",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="hello %s",
            args=("world",),
            exc_info=None,
        )
        output = json.loads(formatter.format(record))
        assert output["level"] == "INFO"
        assert output["logger"] == "test.module"
        assert output["message"] == "hello world"
        assert "timestamp" in output

    def test_exception_included(self) -> None:
        formatter = JSONFormatter()
        try:
            raise ValueError("boom")
        except ValueError:
            record = logging.LogRecord(
                name="test",
                level=logging.ERROR,
                pathname="test.py",
                lineno=1,
                msg="something failed",
                args=(),
                exc_info=True,  # type: ignore[arg-type]
            )
            # LogRecord captures exc_info from sys.exc_info() when True
            import sys

            record.exc_info = sys.exc_info()

        output = json.loads(formatter.format(record))
        assert "exception" in output
        assert "ValueError: boom" in output["exception"]

    def test_context_field(self) -> None:
        formatter = JSONFormatter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="with context",
            args=(),
            exc_info=None,
        )
        record.context = {"bucket": "my-bucket", "tei_file": "items/test.xml"}  # type: ignore[attr-defined]
        output = json.loads(formatter.format(record))
        assert output["context"] == {"bucket": "my-bucket", "tei_file": "items/test.xml"}

    def test_no_context_field_when_absent(self) -> None:
        formatter = JSONFormatter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="no context",
            args=(),
            exc_info=None,
        )
        output = json.loads(formatter.format(record))
        assert "context" not in output

    def test_output_is_single_line(self) -> None:
        formatter = JSONFormatter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="multi\nline\nmessage",
            args=(),
            exc_info=None,
        )
        formatted = formatter.format(record)
        assert "\n" not in formatted


class TestConfigureLogging:
    def test_replaces_existing_handlers(self) -> None:
        root = logging.getLogger()
        root.addHandler(logging.StreamHandler())
        assert len(root.handlers) >= 1

        configure_logging()

        assert len(root.handlers) == 1
        assert isinstance(root.handlers[0].formatter, JSONFormatter)

    def test_sets_level(self) -> None:
        configure_logging(level=logging.DEBUG)
        assert logging.getLogger().level == logging.DEBUG

    def test_json_output_via_logger(self, capsys: pytest.CaptureFixture[str]) -> None:
        configure_logging()
        test_logger = logging.getLogger("integration_test")
        test_logger.info("test message", extra={"context": {"key": "value"}})

        captured = capsys.readouterr()
        output = json.loads(captured.out.strip())
        assert output["message"] == "test message"
        assert output["context"] == {"key": "value"}
