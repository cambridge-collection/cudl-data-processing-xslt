"""Custom exception hierarchy for error classification.

Enables Lambda to distinguish retryable (transient) failures from
permanent ones, driving correct retry/DLQ behaviour.
"""

from __future__ import annotations


class ProcessingError(Exception):
    """Base for all processing errors."""


class TransientError(ProcessingError):
    """Retryable: network, throttle, service unavailable."""


class PermanentError(ProcessingError):
    """Non-retryable: bad input, config, missing data."""


class ConfigError(PermanentError):
    """Missing or invalid configuration."""
