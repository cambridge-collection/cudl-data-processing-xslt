"""Tests for per-object metadata upload: SHA and release-status.

Covers spec tests (a)-(h), (k)-(m).
"""

from __future__ import annotations

import hashlib
import os
import tempfile
from unittest import mock

import boto3
import pytest
from botocore.exceptions import ClientError
from moto import mock_aws

from exceptions import TransientError
from s3_ops import _upload_single_file, upload_dist

BUCKET = "test-output-bucket"


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _create_dist_file(dist_dir: str, subdir: str, filename: str, content: str) -> str:
    """Create a file in the dist directory and return its path."""
    d = os.path.join(dist_dir, subdir)
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, filename)
    with open(path, "w") as f:
        f.write(content)
    return path


def _create_bucket() -> None:
    s3 = boto3.client("s3", region_name="eu-west-1")
    s3.create_bucket(
        Bucket=BUCKET,
        CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
    )


# ---------------------------------------------------------------------------
# (a) Both flags false — unconditional upload
# ---------------------------------------------------------------------------


@mock_aws
class TestBothFlagsDisabled:
    def test_uploads_all_files_unconditionally(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", '{"id": 1}')
            upload_dist(dist_dir, BUCKET)

        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b'{"id": 1}'

    def test_uploads_even_when_dest_exists(self) -> None:
        """With flags disabled, always upload even if dest already exists."""
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.put_object(Bucket=BUCKET, Key="json/item.json", Body=b"old")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "new")
            upload_dist(dist_dir, BUCKET)

        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"new"

    def test_no_metadata_on_uploaded_objects(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "data")
            upload_dist(dist_dir, BUCKET)

        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert head.get("Metadata", {}) == {}

    def test_dest_missing_uploads_ok(self) -> None:
        """When dest doesn't exist and flags disabled, uploads normally."""
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "content")
            upload_dist(dist_dir, BUCKET)

        resp = s3.list_objects_v2(Bucket=BUCKET)
        assert resp["KeyCount"] == 1


# ---------------------------------------------------------------------------
# (b, c) SHA metadata only
# ---------------------------------------------------------------------------


@mock_aws
class TestShaMetadataOnly:
    def test_uploads_when_dest_missing(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "content")
            upload_dist(dist_dir, BUCKET, enable_sha_metadata=True)

        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert "content-sha256" in head["Metadata"]

    def test_uploads_when_dest_sha_missing(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.put_object(Bucket=BUCKET, Key="json/item.json", Body=b"old")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "new-content")
            upload_dist(dist_dir, BUCKET, enable_sha_metadata=True)

        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"new-content"

    def test_uploads_when_dest_sha_differs(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"old",
            Metadata={"content-sha256": "wrong-sha"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "new-data")
            upload_dist(dist_dir, BUCKET, enable_sha_metadata=True)

        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"new-data"
        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert head["Metadata"]["content-sha256"] == _sha256(b"new-data")

    def test_skips_when_dest_sha_matches(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        content = b"same-content"
        sha = _sha256(content)
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"original-body",
            Metadata={"content-sha256": sha},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", content.decode())
            upload_dist(dist_dir, BUCKET, enable_sha_metadata=True)

        # Body unchanged — upload was skipped
        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"original-body"

    def test_no_release_status_metadata_generated(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "data")
            upload_dist(dist_dir, BUCKET, enable_sha_metadata=True)

        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert "content-sha256" in head["Metadata"]
        assert "release-status" not in head["Metadata"]


# ---------------------------------------------------------------------------
# (d, e) Release-status metadata only
# ---------------------------------------------------------------------------


@mock_aws
class TestReleaseStatusMetadataOnly:
    def test_uploads_when_dest_missing(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "content")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_release_status_metadata=True,
                release_status="released",
            )

        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert head["Metadata"]["release-status"] == "released"

    def test_uploads_when_dest_release_status_missing(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.put_object(Bucket=BUCKET, Key="json/item.json", Body=b"old")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "new")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_release_status_metadata=True,
                release_status="draft",
            )

        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"new"

    def test_uploads_when_dest_release_status_differs(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"old",
            Metadata={"release-status": "draft"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "new")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_release_status_metadata=True,
                release_status="released",
            )

        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert head["Metadata"]["release-status"] == "released"

    def test_uploads_even_when_release_status_matches(self) -> None:
        """Release-status is not authoritative for content: always upload when SHA is off."""
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"original-body",
            Metadata={"release-status": "released"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "local-content")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_release_status_metadata=True,
                release_status="released",
            )

        # Uploaded — release-status matching never causes a skip
        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"local-content"

    def test_no_sha_metadata_generated(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "data")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_release_status_metadata=True,
                release_status="draft",
            )

        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert "release-status" in head["Metadata"]
        assert "content-sha256" not in head["Metadata"]


# ---------------------------------------------------------------------------
# (f, g) Both flags enabled
# ---------------------------------------------------------------------------


@mock_aws
class TestBothMetadataEnabled:
    def test_uploads_when_dest_missing(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "content")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_sha_metadata=True,
                enable_release_status_metadata=True,
                release_status="released",
            )

        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert "content-sha256" in head["Metadata"]
        assert head["Metadata"]["release-status"] == "released"

    def test_uploads_when_sha_missing_on_dest(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"old",
            Metadata={"release-status": "released"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "new")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_sha_metadata=True,
                enable_release_status_metadata=True,
                release_status="released",
            )

        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"new"

    def test_uploads_when_release_status_missing_on_dest(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        sha = _sha256(b"same")
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"old",
            Metadata={"content-sha256": sha},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "same")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_sha_metadata=True,
                enable_release_status_metadata=True,
                release_status="released",
            )

        # Uploaded because release-status was missing on dest
        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert head["Metadata"]["release-status"] == "released"

    def test_uploads_when_sha_differs(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"old",
            Metadata={"content-sha256": "wrong", "release-status": "released"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "new-data")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_sha_metadata=True,
                enable_release_status_metadata=True,
                release_status="released",
            )

        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"new-data"

    def test_uploads_when_release_status_differs(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        sha = _sha256(b"same")
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"old",
            Metadata={"content-sha256": sha, "release-status": "draft"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "same")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_sha_metadata=True,
                enable_release_status_metadata=True,
                release_status="released",
            )

        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert head["Metadata"]["release-status"] == "released"

    def test_skips_when_both_match(self) -> None:
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        content = b"stable-content"
        sha = _sha256(content)
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"original-body",
            Metadata={"content-sha256": sha, "release-status": "released"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", content.decode())
            upload_dist(
                dist_dir,
                BUCKET,
                enable_sha_metadata=True,
                enable_release_status_metadata=True,
                release_status="released",
            )

        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"original-body"


# ---------------------------------------------------------------------------
# (h) Disabled fields do not affect the upload decision
# ---------------------------------------------------------------------------


@mock_aws
class TestDisabledFieldsIgnored:
    def test_sha_only_ignores_differing_release_status(self) -> None:
        """With only SHA enabled, a differing release-status on dest is ignored."""
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        content = b"stable"
        sha = _sha256(content)
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"original-body",
            Metadata={"content-sha256": sha, "release-status": "wrong-status"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", content.decode())
            upload_dist(dist_dir, BUCKET, enable_sha_metadata=True)

        # Skipped — SHA matches, release-status difference is irrelevant
        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"original-body"

    def test_release_status_only_always_uploads(self) -> None:
        """With SHA off, no skip is ever taken — release-status alone cannot gate freshness."""
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"original-body",
            Metadata={"content-sha256": "wrong-sha", "release-status": "released"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "different-content")
            upload_dist(
                dist_dir,
                BUCKET,
                enable_release_status_metadata=True,
                release_status="released",
            )

        # Uploaded — without SHA enabled the changed content is always written
        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"different-content"

    def test_sha_only_missing_release_status_on_dest_does_not_trigger(self) -> None:
        """With only SHA enabled, missing release-status on dest doesn't trigger upload."""
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")
        content = b"stable"
        sha = _sha256(content)
        # Dest has matching SHA but NO release-status
        s3.put_object(
            Bucket=BUCKET,
            Key="json/item.json",
            Body=b"original-body",
            Metadata={"content-sha256": sha},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", content.decode())
            upload_dist(dist_dir, BUCKET, enable_sha_metadata=True)

        obj = s3.get_object(Bucket=BUCKET, Key="json/item.json")
        assert obj["Body"].read() == b"original-body"


# ---------------------------------------------------------------------------
# (k) S3 keys, content-type, and metadata fields on uploaded objects
# ---------------------------------------------------------------------------


@mock_aws
class TestUploadedObjectMetadata:
    def test_correct_key_content_type_and_metadata(self) -> None:
        """Uploaded objects have correct S3 key, content-type, and only enabled metadata."""
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            # html → html prefix (identity mapping)
            html_dir = os.path.join(
                dist_dir, "html", "data", "tei", "MS-ADD-03975"
            )
            os.makedirs(html_dir)
            with open(os.path.join(html_dir, "MS-ADD-03975-001.html"), "w") as f:
                f.write("<html>page</html>")

            upload_dist(
                dist_dir,
                BUCKET,
                enable_sha_metadata=True,
                enable_release_status_metadata=True,
                release_status="released",
            )

        key = "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html"
        head = s3.head_object(Bucket=BUCKET, Key=key)
        assert "html" in head["ContentType"]
        assert head["Metadata"]["content-sha256"] == _sha256(b"<html>page</html>")
        assert head["Metadata"]["release-status"] == "released"

    def test_only_enabled_metadata_present(self) -> None:
        """With only SHA enabled, release-status must not appear."""
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "item.json", "data")
            upload_dist(dist_dir, BUCKET, enable_sha_metadata=True)

        head = s3.head_object(Bucket=BUCKET, Key="json/item.json")
        assert "content-sha256" in head["Metadata"]
        assert "release-status" not in head["Metadata"]


# ---------------------------------------------------------------------------
# (l) Thread pool: independent SHA per file, shared release-status
# ---------------------------------------------------------------------------


@mock_aws
class TestThreadPoolMetadata:
    def test_independent_sha_shared_release_status(self) -> None:
        """Each file gets its own SHA; all share the same release-status."""
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_dist_file(dist_dir, "json", "a.json", "content-a")
            _create_dist_file(dist_dir, "json", "b.json", "content-b")
            _create_dist_file(dist_dir, "dp-json", "c.json", "content-c")
            upload_dist(
                dist_dir,
                BUCKET,
                max_workers=3,
                enable_sha_metadata=True,
                enable_release_status_metadata=True,
                release_status="released",
            )

        a_head = s3.head_object(Bucket=BUCKET, Key="json/a.json")
        b_head = s3.head_object(Bucket=BUCKET, Key="json/b.json")
        c_head = s3.head_object(Bucket=BUCKET, Key="dp-json/c.json")

        # Each file has its own SHA
        assert a_head["Metadata"]["content-sha256"] == _sha256(b"content-a")
        assert b_head["Metadata"]["content-sha256"] == _sha256(b"content-b")
        assert c_head["Metadata"]["content-sha256"] == _sha256(b"content-c")
        # All three are different
        shas = {
            a_head["Metadata"]["content-sha256"],
            b_head["Metadata"]["content-sha256"],
            c_head["Metadata"]["content-sha256"],
        }
        assert len(shas) == 3

        # All share the same release-status
        assert a_head["Metadata"]["release-status"] == "released"
        assert b_head["Metadata"]["release-status"] == "released"
        assert c_head["Metadata"]["release-status"] == "released"


# ---------------------------------------------------------------------------
# (m) Partial upload failure unchanged for files selected for upload
# ---------------------------------------------------------------------------


@mock_aws
class TestPartialUploadFailureWithMetadata:
    def test_partial_failure_raises_transient_error(self) -> None:
        """Error injection: one upload fails, TransientError reports correct counts."""
        _create_bucket()

        failing_key = "json/b.json"
        original = _upload_single_file

        def upload_or_fail(
            s3_client: object,
            file_path: str,
            bucket: str,
            s3_key: str,
            metadata: object = None,
        ) -> None:
            if s3_key == failing_key:
                raise ClientError(
                    {"Error": {"Code": "InternalError", "Message": "injected"}},
                    "PutObject",
                )
            original(s3_client, file_path, bucket, s3_key)  # type: ignore[arg-type]

        with tempfile.TemporaryDirectory() as dist_dir:
            for name in ("a.json", "b.json", "c.json"):
                _create_dist_file(dist_dir, "json", name, f"content-{name}")

            with mock.patch("s3_ops._upload_single_file", side_effect=upload_or_fail):
                with pytest.raises(TransientError, match=r"1/3 uploads failed"):
                    upload_dist(
                        dist_dir,
                        BUCKET,
                        max_workers=1,
                        enable_sha_metadata=True,
                        enable_release_status_metadata=True,
                        release_status="released",
                    )
