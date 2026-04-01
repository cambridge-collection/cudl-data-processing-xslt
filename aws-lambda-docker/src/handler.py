"""AWS Lambda handler for TEI processing via SQS.

Supports SQS partial batch failure reporting. The event source mapping
must have ``FunctionResponseTypes: ["ReportBatchItemFailures"]`` enabled.
"""

from __future__ import annotations

import json
import logging
from typing import Any

from config import DIST_DIR, SOURCE_DIR, Config
from exceptions import PermanentError
from logging_config import configure_logging
from processor import clean_dist, clean_source_workspace, run_ant, setup_workspace
from s3_ops import delete_outputs, download_file, upload_dist

configure_logging()
logger = logging.getLogger(__name__)


def _parse_record(record: dict[str, Any]) -> tuple[str, str, str]:
    """Extract event_name, bucket, key from a single SQS record.

    Raises PermanentError with raw record context on parse failure.
    """
    try:
        body = json.loads(record["body"])
        s3_event = body["Records"][0]
        return (
            s3_event["eventName"],
            s3_event["s3"]["bucket"]["name"],
            s3_event["s3"]["object"]["key"],
        )
    except (KeyError, IndexError, json.JSONDecodeError) as e:
        logger.error("Malformed record", extra={"context": {"raw_record": record}})
        raise PermanentError(f"Cannot parse SQS record: {e}") from e


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Lambda handler for SQS events containing S3 notifications.

    Processes every record in the batch individually and returns
    ``batchItemFailures`` so SQS only retries the records that failed.
    Both transient and permanent errors are reported as failures so that
    permanent errors exhaust their receive count and reach the DLQ via
    the SQS redrive policy.
    """
    config = Config.from_env()
    config.validate_for_aws()
    setup_workspace()

    batch_item_failures: list[dict[str, str]] = []

    for record in event["Records"]:
        message_id = record["messageId"]
        try:
            event_name, s3_bucket, tei_file = _parse_record(record)

            logger.info(
                "Processing event",
                extra={
                    "context": {
                        "message_id": message_id,
                        "event": event_name,
                        "bucket": s3_bucket,
                        "tei_file": tei_file,
                    }
                },
            )

            if event_name.startswith("ObjectCreated"):
                _handle_created(config, s3_bucket, tei_file)
            elif event_name.startswith("ObjectRemoved"):
                _handle_removed(config, tei_file)
            else:
                raise PermanentError(f"Unsupported event: {event_name}")

        except PermanentError:
            logger.exception("Permanent failure for %s", message_id)
            batch_item_failures.append({"itemIdentifier": message_id})
        except Exception:
            logger.exception("Transient/unexpected failure for %s", message_id)
            batch_item_failures.append({"itemIdentifier": message_id})

    return {"batchItemFailures": batch_item_failures}


def _handle_created(config: Config, s3_bucket: str, tei_file: str) -> None:
    """Handle ObjectCreated: download source, transform, upload outputs."""
    local_path = f"{SOURCE_DIR}/{tei_file}"

    try:
        clean_source_workspace()
        download_file(s3_bucket, tei_file, local_path)
        run_ant(config, tei_file)
        upload_dist(DIST_DIR, config.aws_output_bucket)
    finally:
        clean_dist()
        clean_source_workspace()

    logger.info(
        "Finished processing",
        extra={"context": {"bucket": s3_bucket, "tei_file": tei_file}},
    )


def _handle_removed(config: Config, tei_file: str) -> None:
    """Handle ObjectRemoved: delete all derived outputs."""
    ctx = {"bucket": config.aws_output_bucket, "tei_file": tei_file}
    logger.info("Removing outputs", extra={"context": ctx})
    delete_outputs(config.aws_output_bucket, tei_file)
    logger.info("All outputs removed", extra={"context": ctx})
