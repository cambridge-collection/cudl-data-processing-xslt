"""S3 operations using boto3."""

from __future__ import annotations

import hashlib
import logging
import mimetypes
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from fnmatch import fnmatch
from typing import TYPE_CHECKING, Any

import boto3
from botocore.config import Config as BotoConfig
from botocore.exceptions import ClientError

from exceptions import PermanentError, TransientError

if TYPE_CHECKING:
    from mypy_boto3_s3.client import S3Client
    from mypy_boto3_s3.type_defs import ObjectIdentifierTypeDef

logger = logging.getLogger(__name__)

S3_RETRY_CONFIG = BotoConfig(retries={"max_attempts": 3, "mode": "adaptive"})


def _s3_client() -> S3Client:
    """Create an S3 client with adaptive retry."""
    return boto3.client("s3", config=S3_RETRY_CONFIG)


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
    ("html", "html"),
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


def _compute_sha256(file_path: str) -> str:
    """Compute lowercase hex SHA-256 of file contents."""
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def _dest_metadata_matches(
    s3: S3Client,
    bucket: str,
    s3_key: str,
    local_metadata: dict[str, str],
) -> bool:
    """Check if destination object metadata matches for all enabled fields.

    Returns True only when the destination exists and every key in
    local_metadata is present with the same value.
    """
    try:
        response = s3.head_object(Bucket=bucket, Key=s3_key)
    except ClientError as e:
        code = e.response["Error"].get("Code", "")
        if code in ("404", "NoSuchKey"):
            return False
        raise
    dest_metadata = response.get("Metadata", {})
    return all(dest_metadata.get(k) == v for k, v in local_metadata.items())


_PERMANENT_S3_CODES = frozenset({"NoSuchKey", "404", "NoSuchBucket", "AccessDenied", "403"})


def download_file(bucket: str, key: str, local_path: str) -> None:
    """Download a file from S3 to a local path."""
    s3 = _s3_client()
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    logger.info("Downloading s3://%s/%s to %s", bucket, key, local_path)
    try:
        s3.download_file(bucket, key, local_path)
    except ClientError as e:
        code = e.response["Error"].get("Code", "")
        ctx = {"bucket": bucket, "key": key, "error_code": code}
        if code in _PERMANENT_S3_CODES:
            logger.error("S3 download permanent failure", extra={"context": ctx})
            raise PermanentError(f"Source not found: s3://{bucket}/{key} ({code})") from e
        logger.error("S3 download transient failure", extra={"context": ctx})
        raise TransientError(f"S3 download failed: s3://{bucket}/{key} ({code})") from e


MAX_UPLOAD_WORKERS = 10


def _upload_single_file(
    s3: S3Client,
    file_path: str,
    bucket: str,
    s3_key: str,
    metadata: dict[str, str] | None = None,
) -> None:
    """Upload a single file to S3 with correct content type and optional metadata."""
    extra_args: dict[str, Any] = {}
    content_type = _get_content_type(file_path)
    if content_type:
        extra_args["ContentType"] = content_type
    if metadata:
        extra_args["Metadata"] = metadata
    s3.upload_file(file_path, bucket, s3_key, ExtraArgs=extra_args)


def _process_and_upload(
    s3: S3Client,
    file_path: str,
    bucket: str,
    s3_key: str,
    *,
    enable_sha_metadata: bool = False,
    enable_release_status_metadata: bool = False,
    release_status: str | None = None,
) -> bool:
    """Compute metadata, check destination, and upload if needed.

    Returns True if the file was uploaded, False if skipped.
    """
    metadata_enabled = enable_sha_metadata or enable_release_status_metadata

    metadata: dict[str, str] = {}
    if enable_sha_metadata:
        metadata["content-sha256"] = _compute_sha256(file_path)
    if enable_release_status_metadata and release_status is not None:
        metadata["release-status"] = release_status

    if metadata_enabled and _dest_metadata_matches(s3, bucket, s3_key, metadata):
        logger.debug("Skipping %s (metadata unchanged)", s3_key)
        return False

    _upload_single_file(s3, file_path, bucket, s3_key, metadata=metadata or None)
    return True


def upload_dist(
    dist_dir: str,
    bucket: str,
    *,
    max_workers: int = MAX_UPLOAD_WORKERS,
    enable_sha_metadata: bool = False,
    enable_release_status_metadata: bool = False,
    release_status: str | None = None,
) -> None:
    """Upload dist directory contents to S3 with correct prefix mapping.

    Uses a thread pool for concurrent uploads since S3 PutObject is I/O-bound.
    When metadata flags are enabled, compares per-object metadata before uploading
    and skips unchanged files.
    """
    s3 = _s3_client()

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
            pool.submit(
                _process_and_upload,
                s3,
                file_path,
                bucket,
                s3_key,
                enable_sha_metadata=enable_sha_metadata,
                enable_release_status_metadata=enable_release_status_metadata,
                release_status=release_status,
            ): s3_key
            for file_path, s3_key in uploads
        }
        errors: list[str] = []
        uploaded = 0
        skipped = 0
        for future in as_completed(futures):
            s3_key = futures[future]
            exc = future.exception()
            if exc is not None:
                logger.error("Upload failed: %s", s3_key, extra={"context": {"error": str(exc)}})
                errors.append(s3_key)
            elif future.result():
                uploaded += 1
            else:
                skipped += 1

    if errors:
        logger.error(
            "Partial upload failure",
            extra={
                "context": {"uploaded": uploaded, "failed": len(errors), "failed_keys": errors}
            },
        )
        raise TransientError(f"{len(errors)}/{len(uploads)} uploads failed: {errors}")

    logger.info("Upload complete: %d uploaded, %d skipped (unchanged)", uploaded, skipped)


def reconcile_stale_page_html(
    dist_dir: str,
    bucket: str,
    tei_file: str,
) -> None:
    """Delete stale page HTML for the current item from the destination bucket.

    Compares the full set of local page HTML files against the destination
    and deletes any destination objects that are no longer present locally.

    Raises TransientError on S3 list or delete failures so the record can retry.
    """
    filename = os.path.splitext(os.path.basename(tei_file))[0]
    containing_dir = os.path.dirname(tei_file)
    html_inner_path = containing_dir.removeprefix("items/")

    s3_prefix = f"html/{html_inner_path}/"
    pattern = f"{filename}-*.html"

    # Enumerate local page HTML basenames for this item
    local_html_dir = os.path.join(dist_dir, "html", html_inner_path)
    local_basenames: set[str] = set()
    if os.path.isdir(local_html_dir):
        for f in os.listdir(local_html_dir):
            if fnmatch(f, pattern):
                local_basenames.add(f)

    # Find stale destination objects
    s3 = _s3_client()
    try:
        paginator = s3.get_paginator("list_objects_v2")
        to_delete: list[ObjectIdentifierTypeDef] = []

        for page in paginator.paginate(Bucket=bucket, Prefix=s3_prefix):
            for obj in page.get("Contents", []):
                key = obj["Key"]
                basename = os.path.basename(key)
                if fnmatch(basename, pattern) and basename not in local_basenames:
                    to_delete.append({"Key": key})

        if not to_delete:
            return

        logger.info(
            "Deleting %d stale page HTML objects for %s",
            len(to_delete),
            tei_file,
            extra={"context": {"keys": [d["Key"] for d in to_delete]}},
        )
        for i in range(0, len(to_delete), 1000):
            batch = to_delete[i : i + 1000]
            s3.delete_objects(Bucket=bucket, Delete={"Objects": batch})
    except ClientError as e:
        raise TransientError(f"Stale page HTML reconciliation failed for {tei_file}: {e}") from e


def delete_outputs(bucket: str, tei_file: str) -> None:
    """Delete all derived outputs for a TEI file from S3."""
    s3 = _s3_client()
    filename = os.path.splitext(os.path.basename(tei_file))[0]
    containing_dir = os.path.dirname(tei_file)
    html_inner_path = containing_dir.removeprefix("items/")

    # Direct key deletions
    direct_keys = [
        f"json/{filename}.json",
        f"solr-json/{filename}.json",
        f"dp-json/{filename}.json",
        f"core-xml/{tei_file}",
        tei_file,
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
