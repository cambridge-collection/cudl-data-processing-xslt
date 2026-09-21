"""Tests for s3_ops.delete_outputs — key generation and pattern matching."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import boto3
import pytest
from botocore.exceptions import ClientError
from moto import mock_aws

from exceptions import PermanentError, TransientError
from s3_ops import delete_outputs, delete_superseded_outputs

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


def _item_family_keys(prefix: str) -> list[str]:
    """Every derived-output key for the test item under one location prefix."""
    stem = "MS-ADD-03975"
    return [
        f"{prefix}json/{stem}.json",
        f"{prefix}solr-json/{stem}.json",
        f"{prefix}dp-json/{stem}.json",
        f"{prefix}core-xml/{TEI_FILE}",
        f"{prefix}{TEI_FILE}",  # tei-full
        f"{prefix}html/data/tei/{stem}/{stem}-001.html",
        f"{prefix}page-xml/items/data/tei/{stem}/{stem}-001.xml",
    ]


@mock_aws
class TestDeleteSupersededOutputs:
    """Surgical cleanup deletes the whole opposite-location family, and only it."""

    def _setup_bucket(self):
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )
        for key in _item_family_keys("") + _item_family_keys("unreleased/"):
            s3.put_object(Bucket=BUCKET, Key=key, Body=b"data")
        return s3

    def test_unreleased_build_cleans_released_family(self, tmp_path) -> None:
        s3 = self._setup_bucket()
        # A populated dist/unreleased/ marks this run's item as unreleased.
        (tmp_path / "unreleased" / "solr-json").mkdir(parents=True)
        (tmp_path / "unreleased" / "solr-json" / "MS-ADD-03975.json").write_text("{}")

        delete_superseded_outputs(str(tmp_path), BUCKET, TEI_FILE)

        remaining = sorted(
            o["Key"] for o in s3.list_objects_v2(Bucket=BUCKET).get("Contents", [])
        )
        assert remaining == sorted(_item_family_keys("unreleased/"))

    def test_released_build_cleans_unreleased_family(self, tmp_path) -> None:
        s3 = self._setup_bucket()
        (tmp_path / "solr-json").mkdir(parents=True)
        (tmp_path / "solr-json" / "MS-ADD-03975.json").write_text("{}")

        delete_superseded_outputs(str(tmp_path), BUCKET, TEI_FILE)

        remaining = sorted(
            o["Key"] for o in s3.list_objects_v2(Bucket=BUCKET).get("Contents", [])
        )
        assert remaining == sorted(_item_family_keys(""))

    def test_absent_opposite_location_leaves_released_family(self, tmp_path) -> None:
        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )
        for key in _item_family_keys(""):
            s3.put_object(Bucket=BUCKET, Key=key, Body=b"data")
        (tmp_path / "solr-json").mkdir(parents=True)

        delete_superseded_outputs(str(tmp_path), BUCKET, TEI_FILE)

        remaining = sorted(
            o["Key"] for o in s3.list_objects_v2(Bucket=BUCKET).get("Contents", [])
        )
        assert remaining == sorted(_item_family_keys(""))


class TestDeleteSupersededIssuesNoBlindDeletes:
    """No DeleteObject may be issued for a key that isn't there.

    Depending on the bucket's versioning state, a delete of an absent key may
    write a delete marker and emit an ObjectRemoved event rather than being a
    no-op. Asserting on resulting bucket state cannot catch that — the state is
    unchanged either way — so these assert on the calls actually made.
    """

    def _mock_s3(self, present_keys: set[str]) -> MagicMock:
        """An S3 client where only ``present_keys`` exist; pattern lists are empty."""
        mock_s3 = MagicMock()

        def head_object(Bucket: str, Key: str):  # noqa: N803 - boto3 kwarg names
            if Key in present_keys:
                return {"Metadata": {}}
            raise ClientError({"Error": {"Code": "404", "Message": "Not Found"}}, "HeadObject")

        mock_s3.head_object.side_effect = head_object
        mock_paginator = MagicMock()
        mock_paginator.paginate.return_value = []
        mock_s3.get_paginator.return_value = mock_paginator
        return mock_s3

    def test_absent_opposite_location_issues_zero_deletes(self, tmp_path) -> None:
        mock_s3 = self._mock_s3(present_keys=set())
        (tmp_path / "solr-json").mkdir(parents=True)

        with patch("s3_ops._s3_client", return_value=mock_s3):
            delete_superseded_outputs(str(tmp_path), BUCKET, TEI_FILE)

        assert mock_s3.delete_object.call_count == 0

    def test_present_opposite_location_still_deletes(self, tmp_path) -> None:
        present = set(_item_family_keys("unreleased/"))
        mock_s3 = self._mock_s3(present_keys=present)
        (tmp_path / "solr-json").mkdir(parents=True)

        with patch("s3_ops._s3_client", return_value=mock_s3):
            delete_superseded_outputs(str(tmp_path), BUCKET, TEI_FILE)

        deleted = {c.kwargs["Key"] for c in mock_s3.delete_object.call_args_list}
        # Only the five direct keys go through delete_object; the html and
        # page-xml families are handled by the (empty) paginated pattern sweep.
        assert deleted == {k for k in present if "/html/" not in k and "/page-xml/" not in k}

    def test_mixed_presence_deletes_only_what_exists(self, tmp_path) -> None:
        present = {"unreleased/solr-json/MS-ADD-03975.json"}
        mock_s3 = self._mock_s3(present_keys=present)
        (tmp_path / "solr-json").mkdir(parents=True)

        with patch("s3_ops._s3_client", return_value=mock_s3):
            delete_superseded_outputs(str(tmp_path), BUCKET, TEI_FILE)

        deleted = {c.kwargs["Key"] for c in mock_s3.delete_object.call_args_list}
        assert deleted == present

    def test_head_failure_is_reported_not_swallowed(self, tmp_path) -> None:
        mock_s3 = MagicMock()
        mock_s3.head_object.side_effect = ClientError(
            {"Error": {"Code": "AccessDenied", "Message": "boom"}}, "HeadObject"
        )
        mock_paginator = MagicMock()
        mock_paginator.paginate.return_value = []
        mock_s3.get_paginator.return_value = mock_paginator
        (tmp_path / "solr-json").mkdir(parents=True)

        with (
            patch("s3_ops._s3_client", return_value=mock_s3),
            pytest.raises(PermanentError, match="Failed to delete"),
        ):
            delete_superseded_outputs(str(tmp_path), BUCKET, TEI_FILE)

        assert mock_s3.delete_object.call_count == 0


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
