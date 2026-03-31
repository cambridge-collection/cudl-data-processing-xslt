"""S3 operations using boto3."""

from __future__ import annotations

import logging
import mimetypes
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from fnmatch import fnmatch
from typing import TYPE_CHECKING

import boto3
from botocore.exceptions import ClientError

if TYPE_CHECKING:
    from mypy_boto3_s3.client import S3Client
    from mypy_boto3_s3.type_defs import ObjectIdentifierTypeDef

logger = logging.getLogger(__name__)

FONT_MIME_TYPES: dict[str, str] = {
    ".woff": "font/woff",
    ".woff2": "font/woff2",
    ".ttf": "font/ttf",
    ".otf": "font/otf",
    ".eot": "application/vnd.ms-fontobject",
}

# Mapping: (local subdirectory under dist/, S3 key prefix)
DIST_TO_S3_MAPPING: list[tuple[str, str]] = [
    ("core-xml", "core-xml"),
    ("json", "json"),
    ("solr-json", "solr-json"),
    ("dp-json", "dp-json"),
    ("www/items", "html"),
    ("www/cudl-resources", "html/cudl-resources"),
    ("page-xml", "page-xml"),
    ("items", "items"),
]


def _get_content_type(file_path: str) -> str | None:
    """Get content type, with special handling for font files."""
    ext = os.path.splitext(file_path)[1].lower()
    if ext in FONT_MIME_TYPES:
        return FONT_MIME_TYPES[ext]
    content_type, _ = mimetypes.guess_type(file_path)
    return content_type


def download_file(bucket: str, key: str, local_path: str) -> None:
    """Download a file from S3 to a local path."""
    s3 = boto3.client("s3")
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    logger.info("Downloading s3://%s/%s to %s", bucket, key, local_path)
    s3.download_file(bucket, key, local_path)


MAX_UPLOAD_WORKERS = 10


def _upload_single_file(s3: S3Client, file_path: str, bucket: str, s3_key: str) -> None:
    """Upload a single file to S3 with correct content type."""
    extra_args: dict[str, str] = {}
    content_type = _get_content_type(file_path)
    if content_type:
        extra_args["ContentType"] = content_type
    s3.upload_file(file_path, bucket, s3_key, ExtraArgs=extra_args)


def upload_dist(dist_dir: str, bucket: str, *, max_workers: int = MAX_UPLOAD_WORKERS) -> None:
    """Upload dist directory contents to S3 with correct prefix mapping.

    Uses a thread pool for concurrent uploads since S3 PutObject is I/O-bound.
    """
    s3 = boto3.client("s3")

    # Collect all (local_file, s3_key) pairs first
    uploads: list[tuple[str, str]] = []
    for local_subdir, s3_prefix in DIST_TO_S3_MAPPING:
        local_path = os.path.join(dist_dir, local_subdir)
        if not os.path.isdir(local_path):
            logger.debug("Skipping %s (not found)", local_path)
            continue

        for root, _, files in os.walk(local_path):
            for filename in files:
                file_path = os.path.join(root, filename)
                rel_path = os.path.relpath(file_path, local_path)
                s3_key = f"{s3_prefix}/{rel_path}"
                uploads.append((file_path, s3_key))

    if not uploads:
        logger.info("No files to upload from %s", dist_dir)
        return

    logger.info("Uploading %d files to s3://%s (workers=%d)", len(uploads), bucket, max_workers)

    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = {
            pool.submit(_upload_single_file, s3, file_path, bucket, s3_key): s3_key
            for file_path, s3_key in uploads
        }
        errors: list[str] = []
        for future in as_completed(futures):
            s3_key = futures[future]
            exc = future.exception()
            if exc is not None:
                logger.error("Failed to upload %s: %s", s3_key, exc)
                errors.append(s3_key)

    if errors:
        raise RuntimeError(f"Failed to upload {len(errors)} file(s): {errors}")

    logger.info("Uploaded %d files to s3://%s", len(uploads), bucket)


def delete_outputs(bucket: str, tei_file: str) -> None:
    """Delete all derived outputs for a TEI file from S3."""
    s3 = boto3.client("s3")
    filename = os.path.splitext(os.path.basename(tei_file))[0]
    containing_dir = os.path.dirname(tei_file)
    html_inner_path = containing_dir.removeprefix("items/")

    # Direct key deletions
    direct_keys = [
        f"json/{filename}.json",
        f"solr-json/{filename}.json",
        f"dp-json/{filename}.json",
        f"core-xml/{tei_file}",
        f"items/{tei_file}",
    ]

    for key in direct_keys:
        logger.info("Deleting s3://%s/%s", bucket, key)
        try:
            s3.delete_object(Bucket=bucket, Key=key)
        except ClientError as e:
            logger.warning("Failed to delete s3://%s/%s: %s", bucket, key, e)

    # Pattern-based deletions (HTML and page-xml with glob patterns)
    _delete_matching(s3, bucket, f"html/{html_inner_path}/", f"{filename}-*.html")
    _delete_matching(s3, bucket, f"page-xml/{containing_dir}/", f"{filename}-*.xml")


def _delete_matching(
    s3: S3Client,
    bucket: str,
    prefix: str,
    pattern: str,
) -> None:
    """Delete S3 objects matching a prefix and filename glob pattern."""
    paginator = s3.get_paginator("list_objects_v2")
    to_delete: list[ObjectIdentifierTypeDef] = []

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if fnmatch(os.path.basename(key), pattern):
                to_delete.append({"Key": key})

    if to_delete:
        logger.info(
            "Deleting %d objects matching %s%s from s3://%s",
            len(to_delete),
            prefix,
            pattern,
            bucket,
        )
        for i in range(0, len(to_delete), 1000):
            batch = to_delete[i : i + 1000]
            s3.delete_objects(Bucket=bucket, Delete={"Objects": batch})
