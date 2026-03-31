"""Tests for s3_ops.delete_outputs — key generation and pattern matching."""

from __future__ import annotations

import boto3
from moto import mock_aws

from s3_ops import delete_outputs

BUCKET = "test-output-bucket"
TEI_FILE = "items/data/tei/MS-ADD-03975/MS-ADD-03975.xml"


@mock_aws
class TestDeleteOutputs:
    def _setup_bucket(self) -> None:
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )
        return s3

    def test_deletes_direct_keys(self) -> None:
        s3 = self._setup_bucket()

        # Seed direct-key objects
        expected_keys = [
            "json/MS-ADD-03975.json",
            "solr-json/MS-ADD-03975.json",
            "dp-json/MS-ADD-03975.json",
            f"core-xml/{TEI_FILE}",
            f"items/{TEI_FILE}",
        ]
        for key in expected_keys:
            s3.put_object(Bucket=BUCKET, Key=key, Body=b"data")

        delete_outputs(BUCKET, TEI_FILE)

        resp = s3.list_objects_v2(Bucket=BUCKET)
        assert resp.get("KeyCount", 0) == 0

    def test_deletes_html_pattern_matches(self) -> None:
        s3 = self._setup_bucket()

        # html_inner_path = "data/tei/MS-ADD-03975" (items/ prefix stripped)
        html_keys = [
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-003.html",
        ]
        unrelated_key = "html/data/tei/OTHER-ITEM/OTHER-ITEM-001.html"
        for key in html_keys + [unrelated_key]:
            s3.put_object(Bucket=BUCKET, Key=key, Body=b"<html/>")

        delete_outputs(BUCKET, TEI_FILE)

        resp = s3.list_objects_v2(Bucket=BUCKET)
        remaining = [o["Key"] for o in resp.get("Contents", [])]
        assert remaining == [unrelated_key]

    def test_deletes_page_xml_pattern_matches(self) -> None:
        s3 = self._setup_bucket()

        page_keys = [
            f"page-xml/{TEI_FILE.replace('.xml', '')}-001.xml",
            f"page-xml/{TEI_FILE.replace('.xml', '')}-002.xml",
        ]
        # keeping_dir is items/data/tei/MS-ADD-03975
        # pattern is MS-ADD-03975-*.xml under page-xml/items/data/tei/MS-ADD-03975/
        unrelated_key = "page-xml/items/data/tei/OTHER/OTHER-001.xml"
        for key in page_keys + [unrelated_key]:
            s3.put_object(Bucket=BUCKET, Key=key, Body=b"<xml/>")

        delete_outputs(BUCKET, TEI_FILE)

        resp = s3.list_objects_v2(Bucket=BUCKET)
        remaining = [o["Key"] for o in resp.get("Contents", [])]
        assert unrelated_key in remaining
        for k in page_keys:
            assert k not in remaining

    def test_html_inner_path_strips_items_prefix(self) -> None:
        """items/data/tei/X → data/tei/X for the html path."""
        import os

        containing_dir = os.path.dirname(TEI_FILE)
        html_inner_path = containing_dir.removeprefix("items/")
        assert html_inner_path == "data/tei/MS-ADD-03975"

    def test_no_error_on_empty_bucket(self) -> None:
        """Deleting from an empty bucket should not raise."""
        self._setup_bucket()
        delete_outputs(BUCKET, TEI_FILE)  # should not raise
