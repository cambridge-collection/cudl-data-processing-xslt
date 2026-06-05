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

    If enable_sha_metadata is false, then the file is always uploaded.

    If enable_sha_metadata is true, then the file is only uploaded if:
        - the destination's stored SHA differs from the locally built file's
          (or the destination is missing / has no SHA).

    There is one edge case, if both enable_sha_metadata and
    enable_release_status_metadata are true, the file may be uploaded if
    the old release status differs from the current one. This edge case is
    largely just to catch the absence of the release status object metadata
    on the old file.
    """
    metadata: dict[str, str] = {}
    if enable_sha_metadata:
        metadata["content-sha256"] = _compute_sha256(file_path)
    if enable_release_status_metadata and release_status is not None:
        metadata["release-status"] = release_status

    if enable_sha_metadata and _dest_metadata_matches(s3, bucket, s3_key, metadata):
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

    # dist/unreleased/ is a sibling of dist/<type>, so it needs its own walk;
    # its files map to matching unreleased/<prefix> keys.
    locations = [
        (os.path.join(dist_dir, subdir), prefix) for subdir, prefix in DIST_TO_S3_MAPPING
    ] + [
        (os.path.join(dist_dir, "unreleased", subdir), f"unreleased/{prefix}")
        for subdir, prefix in DIST_TO_S3_MAPPING
    ]

    # Collect all (local_file, s3_key) pairs first
    uploads: list[tuple[str, str]] = []
    for local_path, s3_prefix in locations:
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


def _collect_stale_page_keys(
    s3: S3Client,
    dist_dir: str,
    bucket: str,
    *,
    family: str,
    inner_path: str,
    pattern: str,
) -> list[ObjectIdentifierTypeDef]:
    """Collect stale per-page object keys for one output family, both locations.

    A key is stale when it matches the item's per-page glob but has no local
    counterpart. Released (``<family>/``) and unreleased (``unreleased/<family>/``)
    are reconciled independently against their own local subtree.
    """
    paginator = s3.get_paginator("list_objects_v2")
    to_delete: list[ObjectIdentifierTypeDef] = []

    for location_prefix in ("", "unreleased/"):
        local_dir = os.path.join(dist_dir, location_prefix.rstrip("/"), family, inner_path)
        local_basenames: set[str] = set()
        if os.path.isdir(local_dir):
            for f in os.listdir(local_dir):
                if fnmatch(f, pattern):
                    local_basenames.add(f)

        s3_prefix = f"{location_prefix}{family}/{inner_path}/"
        for page in paginator.paginate(Bucket=bucket, Prefix=s3_prefix):
            for obj in page.get("Contents", []):
                key = obj["Key"]
                basename = os.path.basename(key)
                if fnmatch(basename, pattern) and basename not in local_basenames:
                    to_delete.append({"Key": key})

    return to_delete


def reconcile_stale_page_outputs(
    dist_dir: str,
    bucket: str,
    tei_file: str,
) -> None:
    """Delete stale per-page outputs (page HTML and page XML) for the item.

    Compares the full set of local per-page files against the destination and
    deletes any destination objects that are no longer present locally, across
    both the released and unreleased (``unreleased/``) locations. Per-item
    single-file outputs (json, core-xml, ...) are overwritten in place by the
    upload and so need no reconciliation.

    Note the differing key layouts: ``page-xml`` keeps the source ``items/``
    segment, whereas ``html`` strips it.

    Raises TransientError on an S3 list failure or a retryable delete failure so
    the record can retry; an all-permanent delete-failure set raises
    PermanentError (routing the record to the DLQ), matching the cleanup path.
    """
    filename = os.path.splitext(os.path.basename(tei_file))[0]
    containing_dir = os.path.dirname(tei_file)
    html_inner_path = containing_dir.removeprefix("items/")

    families = [
        ("html", html_inner_path, f"{filename}-*.html"),
        ("page-xml", containing_dir, f"{filename}-*.xml"),
    ]

    s3 = _s3_client()
    to_delete: list[ObjectIdentifierTypeDef] = []
    try:
        for family, inner_path, pattern in families:
            to_delete += _collect_stale_page_keys(
                s3, dist_dir, bucket, family=family, inner_path=inner_path, pattern=pattern
            )
    except ClientError as e:
        raise TransientError(f"Stale per-page reconciliation failed for {tei_file}: {e}") from e

    if not to_delete:
        return

    logger.info(
        "Deleting %d stale per-page objects for %s",
        len(to_delete),
        tei_file,
        extra={"context": {"keys": [d["Key"] for d in to_delete]}},
    )
    failures: list[dict[str, str]] = []
    for i in range(0, len(to_delete), 1000):
        batch = to_delete[i : i + 1000]
        try:
            resp = s3.delete_objects(Bucket=bucket, Delete={"Objects": batch})
        except ClientError as e:
            # Whole-batch request failure: attribute the code to every key in it.
            code = e.response["Error"].get("Code", "")
            failures += [_log_delete_failure(bucket, obj["Key"], code, str(e)) for obj in batch]
            continue
        # delete_objects returns HTTP 200 with per-object failures in "Errors".
        failures += [
            _log_delete_failure(
                bucket, err.get("Key", ""), err.get("Code", ""), err.get("Message", "")
            )
            for err in resp.get("Errors", [])
        ]
    _raise_on_delete_failures(failures, tei_file)


def _log_delete_failure(bucket: str, key: str, code: str, error: str) -> dict[str, str]:
    """Log a single delete failure at ERROR and return it for aggregation."""
    logger.error(
        "Failed to delete object",
        extra={"context": {"bucket": bucket, "key": key, "error_code": code, "error": error}},
    )
    return {"key": key, "error_code": code}


def _delete_item_location(
    s3: S3Client,
    bucket: str,
    tei_file: str,
    location_prefix: str,
) -> list[dict[str, str]]:
    """Delete one location's derived-output family for a TEI file.

    ``location_prefix`` is ``""`` (released) or ``"unreleased/"`` (unreleased).
    """
    filename = os.path.splitext(os.path.basename(tei_file))[0]
    containing_dir = os.path.dirname(tei_file)
    html_inner_path = containing_dir.removeprefix("items/")

    direct_keys = [
        f"{location_prefix}json/{filename}.json",
        f"{location_prefix}solr-json/{filename}.json",
        f"{location_prefix}dp-json/{filename}.json",
        f"{location_prefix}core-xml/{tei_file}",
        f"{location_prefix}{tei_file}",
    ]

    failures: list[dict[str, str]] = []
    for key in direct_keys:
        logger.info("Deleting s3://%s/%s", bucket, key)
        try:
            s3.delete_object(Bucket=bucket, Key=key)
        except ClientError as e:
            failures.append(
                _log_delete_failure(bucket, key, e.response["Error"].get("Code", ""), str(e))
            )

    failures += _delete_matching(
        s3, bucket, f"{location_prefix}html/{html_inner_path}/", f"{filename}-*.html"
    )
    failures += _delete_matching(
        s3, bucket, f"{location_prefix}page-xml/{containing_dir}/", f"{filename}-*.xml"
    )
    return failures


def _raise_on_delete_failures(failures: list[dict[str, str]], tei_file: str) -> None:
    """Re-raise aggregated delete failures once, routing the SQS record.

    Transient errors retry; an all-permanent set (e.g. AccessDenied) raises
    PermanentError so the record exhausts its receive count and reaches the DLQ.
    """
    if not failures:
        return
    codes = {f["error_code"] for f in failures}
    error_cls = PermanentError if codes <= _PERMANENT_S3_CODES else TransientError
    raise error_cls(
        f"Failed to delete {len(failures)} output(s) for {tei_file} (codes: {sorted(codes)})"
    )


def delete_outputs(bucket: str, tei_file: str) -> None:
    """Delete all derived outputs for a TEI file from S3, both locations.

    For a genuine item deletion, where no upload follows, so removing both the
    released root and the unreleased subtree wholesale is correct. Failures are
    collected and re-raised once so a genuine failure fails the SQS record.
    """
    s3 = _s3_client()
    failures: list[dict[str, str]] = []
    for location_prefix in ("", "unreleased/"):
        failures += _delete_item_location(s3, bucket, tei_file, location_prefix)
    _raise_on_delete_failures(failures, tei_file)


def _build_produced_unreleased(dist_dir: str) -> bool:
    """True if this run's build partitioned the item into the unreleased subtree.

    A run processes a single item, so any file under dist/unreleased/ means that
    item is currently unreleased.
    """
    unreleased_root = os.path.join(dist_dir, "unreleased")
    if not os.path.isdir(unreleased_root):
        return False
    return any(files for _, _, files in os.walk(unreleased_root))


def delete_superseded_outputs(dist_dir: str, bucket: str, tei_file: str) -> None:
    """Delete this item's outputs in the location opposite to the one just built.

    On a release-status flip the build writes outputs to the new location while
    the previous run's outputs linger in the old one (stale, and for solr-json
    still indexed). The location is taken from what the build produced rather
    than re-derived, so the cleanup always matches what was uploaded.

    Deliberately surgical — deleting both locations would also remove the
    just-uploaded item and de-index it downstream. A missing opposite location
    is the normal no-flip case and deletes nothing.
    """
    s3 = _s3_client()
    opposite_prefix = "" if _build_produced_unreleased(dist_dir) else "unreleased/"
    failures = _delete_item_location(s3, bucket, tei_file, opposite_prefix)
    _raise_on_delete_failures(failures, tei_file)


def _delete_matching(
    s3: S3Client,
    bucket: str,
    prefix: str,
    pattern: str,
) -> list[dict[str, str]]:
    """Delete S3 objects matching a prefix and filename glob pattern.

    Returns a list of ``{key, error_code}`` dicts for objects that could not be
    deleted (each already logged at ERROR), so the caller can aggregate them.
    """
    paginator = s3.get_paginator("list_objects_v2")
    to_delete: list[ObjectIdentifierTypeDef] = []

    try:
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            for obj in page.get("Contents", []):
                key = obj["Key"]
                if fnmatch(os.path.basename(key), pattern):
                    to_delete.append({"Key": key})
    except ClientError as e:
        # Listing failed, so the keys are unknown: report the prefix itself.
        return [_log_delete_failure(bucket, prefix, e.response["Error"].get("Code", ""), str(e))]

    if not to_delete:
        return []

    logger.info(
        "Deleting %d objects matching %s%s from s3://%s",
        len(to_delete),
        prefix,
        pattern,
        bucket,
    )

    failures: list[dict[str, str]] = []
    for i in range(0, len(to_delete), 1000):
        batch = to_delete[i : i + 1000]
        try:
            resp = s3.delete_objects(Bucket=bucket, Delete={"Objects": batch})
        except ClientError as e:
            # Whole-batch request failure: attribute the code to every key in it.
            code = e.response["Error"].get("Code", "")
            failures += [_log_delete_failure(bucket, obj["Key"], code, str(e)) for obj in batch]
            continue
        # delete_objects returns HTTP 200 with per-object failures in "Errors".
        failures += [
            _log_delete_failure(
                bucket, err.get("Key", ""), err.get("Code", ""), err.get("Message", "")
            )
            for err in resp.get("Errors", [])
        ]
    return failures
