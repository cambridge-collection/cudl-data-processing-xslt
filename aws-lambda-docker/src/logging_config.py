"""Structured JSON logging for CloudWatch."""

from __future__ import annotations

import json
import logging
import os
import sys
from datetime import datetime, timezone


class JSONFormatter(logging.Formatter):
    """Format log records as single-line JSON for CloudWatch."""

    def format(self, record: logging.LogRecord) -> str:
        log_entry: dict[str, object] = {
            "timestamp": datetime.fromtimestamp(
                record.created, tz=timezone.utc  # noqa: UP017
            ).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        if record.exc_info and record.exc_info[0] is not None:
            log_entry["exception"] = self.formatException(record.exc_info)

        if hasattr(record, "source"):
            log_entry["source"] = record.source

        # Merge any extra structured fields passed via `extra={"context": {...}}`
        if hasattr(record, "context") and isinstance(record.context, dict):
            log_entry["context"] = record.context

        return json.dumps(log_entry, default=str)


def configure_logging(*, level: int | None = None) -> None:
    """Configure root logger with JSON output to stdout.

    Level is read from LOG_LEVEL env var (default: INFO).
    """
    if level is None:
        level = getattr(logging, os.environ.get("LOG_LEVEL", "INFO").upper(), logging.INFO)
    root = logging.getLogger()
    root.setLevel(level)

    # Remove existing handlers (Lambda may add its own)
    for h in root.handlers[:]:
        root.removeHandler(h)

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JSONFormatter())
    root.addHandler(handler)
