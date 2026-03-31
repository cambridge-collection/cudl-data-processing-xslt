"""AWS Lambda handler for TEI processing via SQS."""

from __future__ import annotations

import json
import logging
from typing import Any

from config import DIST_DIR, SOURCE_DIR, Config
from processor import clean_dist, clean_source_workspace, run_ant, setup_workspace
from s3_ops import delete_outputs, download_file, upload_dist

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Lambda handler for SQS events containing S3 notifications."""
    config = Config.from_env()
    config.validate_for_aws()
    setup_workspace()

    record = event["Records"][0]
    body = json.loads(record["body"])
    s3_event = body["Records"][0]

    event_name: str = s3_event["eventName"]
    s3_bucket: str = s3_event["s3"]["bucket"]["name"]
    tei_file: str = s3_event["s3"]["object"]["key"]

    logger.info("Event: %s, Bucket: %s, File: %s", event_name, s3_bucket, tei_file)

    if event_name.startswith("ObjectCreated"):
        _handle_created(config, s3_bucket, tei_file)
    elif event_name.startswith("ObjectRemoved"):
        _handle_removed(config, tei_file)
    else:
        raise ValueError(f"Unsupported event: {event_name}")

    return {"statusCode": 200, "body": f"Processed {tei_file}"}


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

    logger.info("Finished processing s3://%s/%s", s3_bucket, tei_file)


def _handle_removed(config: Config, tei_file: str) -> None:
    """Handle ObjectRemoved: delete all derived outputs."""
    logger.info(
        "Removing outputs for %s from s3://%s", tei_file, config.aws_output_bucket
    )
    delete_outputs(config.aws_output_bucket, tei_file)
    logger.info("All outputs removed for %s", tei_file)
