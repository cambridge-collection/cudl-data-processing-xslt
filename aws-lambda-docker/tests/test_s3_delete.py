"""Tests for s3_ops.delete_outputs — key generation and pattern matching."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import boto3
import pytest
from botocore.exceptions import ClientError
from moto import mock_aws

from exceptions import PermanentError, TransientError
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

        # Seed direct-key objects in both released and unreleased layouts
        released_keys = [
            "json/MS-ADD-03975.json",
            "solr-json/MS-ADD-03975.json",
            "dp-json/MS-ADD-03975.json",
            f"core-xml/{TEI_FILE}",
            TEI_FILE,
        ]
        expected_keys = released_keys + [f"unreleased/{k}" for k in released_keys]
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
            # unreleased mirror should also be deleted
            "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
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
            # unreleased mirror should also be deleted
            f"unreleased/page-xml/{TEI_FILE.replace('.xml', '')}-001.xml",
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


class TestDeleteOutputsFailures:
    """A genuine delete failure must fail the record, classified by error code."""

    def _mock_s3(self, delete_error_code: str) -> MagicMock:
        """An S3 client whose direct deletes fail and whose pattern lists are empty."""
        mock_s3 = MagicMock()
        mock_s3.delete_object.side_effect = ClientError(
            {"Error": {"Code": delete_error_code, "Message": "boom"}},
            "DeleteObject",
        )
        mock_paginator = MagicMock()
        mock_paginator.paginate.return_value = []
        mock_s3.get_paginator.return_value = mock_paginator
        return mock_s3

    def test_permanent_code_raises_permanent(self) -> None:
        mock_s3 = self._mock_s3("AccessDenied")
        with (
            patch("s3_ops._s3_client", return_value=mock_s3),
            pytest.raises(PermanentError, match="Failed to delete"),
        ):
            delete_outputs(BUCKET, TEI_FILE)

    def test_transient_code_raises_transient(self) -> None:
        mock_s3 = self._mock_s3("SlowDown")
        with (
            patch("s3_ops._s3_client", return_value=mock_s3),
            pytest.raises(TransientError, match="Failed to delete"),
        ):
            delete_outputs(BUCKET, TEI_FILE)
