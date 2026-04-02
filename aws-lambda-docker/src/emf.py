"""CloudWatch Embedded Metric Format (EMF) emission.

Writes structured JSON to stdout that CloudWatch parses natively
into custom metrics, avoiding extra boto put_metric_data calls.
"""

from __future__ import annotations

import json
import sys
import time

_EMF_NAMESPACE = "CUDL/Processing"


def emit_error_metric(event_type: str, error_type: str) -> None:
    """Emit a single ErrorCount metric via EMF.

    Args:
        event_type: e.g. "ObjectCreated", "ObjectRemoved", "unknown".
        error_type: "transient" or "permanent".
    """
    emf_doc = {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": _EMF_NAMESPACE,
                    "Dimensions": [["EventType", "ErrorType"]],
                    "Metrics": [{"Name": "ErrorCount", "Unit": "Count"}],
                }
            ],
        },
        "EventType": event_type,
        "ErrorType": error_type,
        "ErrorCount": 1,
    }
    # EMF requires a single JSON line on stdout
    print(json.dumps(emf_doc, separators=(",", ":")), file=sys.stdout, flush=True)
