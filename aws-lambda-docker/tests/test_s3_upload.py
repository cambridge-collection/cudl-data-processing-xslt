"""Tests for s3_ops.upload_dist — path mapping and MIME type detection."""

from __future__ import annotations

import os
import tempfile

import boto3
import pytest
from moto import mock_aws

from s3_ops import DIST_TO_S3_MAPPING, _get_content_type, upload_dist

BUCKET = "test-output-bucket"


class TestDistToS3Mapping:
    """Verify the dist/ subdirectory → S3 prefix mapping is correct."""

    def test_mapping_has_expected_entries(self) -> None:
        mapping = dict(DIST_TO_S3_MAPPING)
        assert mapping["core-xml"] == "core-xml"
        assert mapping["json"] == "json"
        assert mapping["solr-json"] == "solr-json"
        assert mapping["dp-json"] == "dp-json"
        assert mapping["www/items"] == "html"
        assert mapping["www/cudl-resources"] == "html/cudl-resources"
        assert mapping["page-xml"] == "page-xml"
        assert mapping["items"] == "items"

    def test_www_items_maps_to_html_not_www(self) -> None:
        """Critical mapping: www/items → html (not www → html)."""
        mapping = dict(DIST_TO_S3_MAPPING)
        assert mapping["www/items"] == "html"
        assert "www" not in mapping  # no bare 'www' prefix


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
            html_dir = os.path.join(dist_dir, "www", "items", "data", "tei", "MS-ADD-03975")
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
            font_dir = os.path.join(dist_dir, "www", "cudl-resources", "fonts")
            os.makedirs(font_dir)
            with open(os.path.join(font_dir, "Cardo.woff2"), "wb") as f:
                f.write(b"\x00woff2data")

            upload_dist(dist_dir, BUCKET)

        obj = s3.get_object(Bucket=BUCKET, Key="html/cudl-resources/fonts/Cardo.woff2")
        assert obj["ContentType"] == "font/woff2"

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
