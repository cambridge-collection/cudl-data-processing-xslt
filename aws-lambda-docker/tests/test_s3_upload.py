"""Tests for s3_ops.upload_dist — path mapping and MIME type detection."""

from __future__ import annotations

import os
import tempfile
import threading
from unittest import mock

import boto3
import pytest
from botocore.exceptions import ClientError
from moto import mock_aws

from exceptions import TransientError
from s3_ops import DIST_TO_S3_MAPPING, _get_content_type, _upload_single_file, upload_dist

BUCKET = "test-output-bucket"


class TestDistToS3Mapping:
    """Verify the dist/ subdirectory → S3 prefix mapping is correct."""

    def test_mapping_has_expected_entries(self) -> None:
        mapping = dict(DIST_TO_S3_MAPPING)
        assert mapping["core-xml"] == "core-xml"
        assert mapping["json"] == "json"
        assert mapping["solr-json"] == "solr-json"
        assert mapping["dp-json"] == "dp-json"
        assert mapping["html"] == "html"
        assert mapping["page-xml"] == "page-xml"
        assert mapping["items"] == "items"

    def test_html_maps_to_html(self) -> None:
        """Critical mapping: html → html (identity)."""
        mapping = dict(DIST_TO_S3_MAPPING)
        assert mapping["html"] == "html"


class TestGetContentType:
    """Font MIME types and standard types."""

    @pytest.mark.parametrize(
        ("ext", "expected"),
        [
            (".woff", "font/woff"),
            (".woff2", "font/woff2"),
            (".ttf", "font/ttf"),
            (".otf", "font/otf"),
            (".eot", "application/vnd.ms-fontobject"),
        ],
    )
    def test_font_mime_types(self, ext: str, expected: str) -> None:
        assert _get_content_type(f"somefont{ext}") == expected

    def test_xml_content_type(self) -> None:
        ct = _get_content_type("file.xml")
        assert ct is not None
        assert "xml" in ct

    def test_json_content_type(self) -> None:
        ct = _get_content_type("file.json")
        assert ct is not None
        assert "json" in ct

    def test_html_content_type(self) -> None:
        ct = _get_content_type("file.html")
        assert ct is not None
        assert "html" in ct


@mock_aws
class TestUploadDist:
    """Integration test: create local dist dirs, upload, verify S3 keys."""

    def test_uploads_json_file(self) -> None:
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            json_dir = os.path.join(dist_dir, "json")
            os.makedirs(json_dir)
            with open(os.path.join(json_dir, "MS-ADD-03975.json"), "w") as f:
                f.write('{"test": true}')

            upload_dist(dist_dir, BUCKET)

        obj = s3.get_object(Bucket=BUCKET, Key="json/MS-ADD-03975.json")
        assert obj["Body"].read() == b'{"test": true}'

    def test_uploads_www_items_to_html_prefix(self) -> None:
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            html_dir = os.path.join(dist_dir, "html", "data", "tei", "MS-ADD-03975")
            os.makedirs(html_dir)
            with open(os.path.join(html_dir, "MS-ADD-03975-001.html"), "w") as f:
                f.write("<html>test</html>")

            upload_dist(dist_dir, BUCKET)

        obj = s3.get_object(Bucket=BUCKET, Key="html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html")
        assert b"<html>" in obj["Body"].read()

    def test_sets_font_content_type(self) -> None:
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            font_dir = os.path.join(dist_dir, "html", "cudl-resources", "fonts")
            os.makedirs(font_dir)
            with open(os.path.join(font_dir, "Cardo.woff2"), "wb") as f:
                f.write(b"\x00woff2data")

            upload_dist(dist_dir, BUCKET)

        obj = s3.get_object(Bucket=BUCKET, Key="html/cudl-resources/fonts/Cardo.woff2")
        assert obj["ContentType"] == "font/woff2"

    def test_uploads_unreleased_subtree(self) -> None:
        """dist/unreleased/<type>/ maps to unreleased/<prefix>/ alongside released."""
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            released = os.path.join(dist_dir, "json")
            os.makedirs(released)
            with open(os.path.join(released, "REL.json"), "w") as f:
                f.write("{}")
            unreleased = os.path.join(dist_dir, "unreleased", "solr-json")
            os.makedirs(unreleased)
            with open(os.path.join(unreleased, "DRAFT.json"), "w") as f:
                f.write("{}")

            upload_dist(dist_dir, BUCKET)

        resp = s3.list_objects_v2(Bucket=BUCKET)
        keys = sorted(obj["Key"] for obj in resp["Contents"])
        assert keys == ["json/REL.json", "unreleased/solr-json/DRAFT.json"]

    def test_skips_missing_subdirs(self) -> None:
        """No error when dist has no matching subdirectories."""
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            upload_dist(dist_dir, BUCKET)  # empty dist, should not raise

        resp = s3.list_objects_v2(Bucket=BUCKET)
        assert resp.get("KeyCount", 0) == 0

    def test_concurrent_upload_multiple_files(self) -> None:
        """Multiple files across different subdirs are all uploaded."""
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            # Create files in 3 different mapped subdirs
            for subdir, name in [
                ("json", "a.json"),
                ("json", "b.json"),
                ("dp-json", "c.json"),
                ("items/data/tei/X", "X.xml"),
            ]:
                d = os.path.join(dist_dir, subdir)
                os.makedirs(d, exist_ok=True)
                with open(os.path.join(d, name), "w") as f:
                    f.write(f"content-{name}")

            upload_dist(dist_dir, BUCKET, max_workers=2)

        resp = s3.list_objects_v2(Bucket=BUCKET)
        keys = sorted(obj["Key"] for obj in resp["Contents"])
        assert keys == [
            "dp-json/c.json",
            "items/data/tei/X/X.xml",
            "json/a.json",
            "json/b.json",
        ]


@mock_aws
class TestUploadDistClientIsolation:
    """Worker threads must never share an S3 client (shared clients segfault)."""

    def test_each_worker_thread_gets_its_own_client(self) -> None:
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )

        original = _upload_single_file
        seen: list[tuple[int, int]] = []
        lock = threading.Lock()

        def record_client(
            s3_client: object,
            file_path: str,
            bucket: str,
            s3_key: str,
            metadata: object = None,
        ) -> None:
            with lock:
                seen.append((threading.get_ident(), id(s3_client)))
            original(s3_client, file_path, bucket, s3_key)  # type: ignore[arg-type]

        with tempfile.TemporaryDirectory() as dist_dir:
            json_dir = os.path.join(dist_dir, "json")
            os.makedirs(json_dir)
            for i in range(20):
                with open(os.path.join(json_dir, f"f{i:02d}.json"), "w") as f:
                    f.write(f"content-{i}")

            with mock.patch("s3_ops._upload_single_file", side_effect=record_client):
                upload_dist(dist_dir, BUCKET, max_workers=4)

        assert len(seen) == 20
        by_client: dict[int, set[int]] = {}
        by_thread: dict[int, set[int]] = {}
        for thread_id, client_id in seen:
            by_client.setdefault(client_id, set()).add(thread_id)
            by_thread.setdefault(thread_id, set()).add(client_id)
        assert all(len(threads) == 1 for threads in by_client.values())
        assert all(len(clients) == 1 for clients in by_thread.values())
        assert len(by_client) == len(by_thread) > 1


@mock_aws
class TestUploadDistErrorInjection:
    """Error injection: partial upload failure raises TransientError with context."""

    def test_partial_failure_raises_transient_error(self) -> None:
        """One failed upload in a batch raises TransientError with failed/total counts and keys."""
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )

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
            for subdir, name in [
                ("json", "a.json"),
                ("json", "b.json"),
                ("json", "c.json"),
            ]:
                d = os.path.join(dist_dir, subdir)
                os.makedirs(d, exist_ok=True)
                with open(os.path.join(d, name), "w") as f:
                    f.write(f"content-{name}")

            with mock.patch("s3_ops._upload_single_file", side_effect=upload_or_fail):
                with pytest.raises(TransientError, match=r"1/3 uploads failed") as exc_info:
                    upload_dist(dist_dir, BUCKET, max_workers=1)

        assert failing_key in str(exc_info.value)
