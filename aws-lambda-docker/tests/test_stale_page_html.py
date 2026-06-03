"""Tests for Phase 7: stale per-page output reconciliation (HTML and page XML).

Covers spec tests (a)-(i).
"""

from __future__ import annotations

import json
import os
import tempfile
from typing import Any
from unittest.mock import MagicMock, patch

import boto3
import pytest
from botocore.exceptions import ClientError
from moto import mock_aws

from exceptions import TransientError
from s3_ops import reconcile_stale_page_outputs

BUCKET = "test-output-bucket"
TEI_FILE = "items/data/tei/MS-ADD-03975/MS-ADD-03975.xml"


def _create_bucket() -> None:
    s3 = boto3.client("s3", region_name="eu-west-1")
    s3.create_bucket(
        Bucket=BUCKET,
        CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
    )


def _create_local_page_html(
    dist_dir: str, item_dir: str, filenames: list[str], *, location_prefix: str = ""
) -> None:
    """Create local page HTML files under dist/{location}html/{item_dir}/.

    ``location_prefix`` is ``""`` (released) or ``"unreleased/"`` (unreleased).
    """
    d = os.path.join(dist_dir, location_prefix.rstrip("/"), "html", item_dir)
    os.makedirs(d, exist_ok=True)
    for fn in filenames:
        with open(os.path.join(d, fn), "w") as f:
            f.write(f"<html>{fn}</html>")


def _create_local_page_xml(
    dist_dir: str, item_dir: str, filenames: list[str], *, location_prefix: str = ""
) -> None:
    """Create local page XML files under dist/{location}page-xml/{item_dir}/.

    ``item_dir`` keeps the source ``items/`` segment, matching the page-xml
    key layout. ``location_prefix`` is ``""`` or ``"unreleased/"``.
    """
    d = os.path.join(dist_dir, location_prefix.rstrip("/"), "page-xml", item_dir)
    os.makedirs(d, exist_ok=True)
    for fn in filenames:
        with open(os.path.join(d, fn), "w") as f:
            f.write(f"<TEI>{fn}</TEI>")


def _put_s3_objects(keys: list[str], body: bytes = b"<html/>") -> None:
    s3 = boto3.client("s3", region_name="eu-west-1")
    for key in keys:
        s3.put_object(Bucket=BUCKET, Key=key, Body=body)


def _list_s3_keys() -> list[str]:
    s3 = boto3.client("s3", region_name="eu-west-1")
    resp = s3.list_objects_v2(Bucket=BUCKET)
    return sorted(o["Key"] for o in resp.get("Contents", []))


# ---------------------------------------------------------------------------
# (a) Stale page HTML is deleted
# ---------------------------------------------------------------------------


@mock_aws
class TestStalePageHtmlDeleted:
    def test_stale_pages_removed(self) -> None:
        """Dest page HTML not in local build is deleted."""
        _create_bucket()
        # Dest has pages 1-3, local only has page 1
        _put_s3_objects([
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-003.html",
        ])

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_local_page_html(
                dist_dir,
                "data/tei/MS-ADD-03975",
                ["MS-ADD-03975-001.html"],
            )
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html" in keys
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html" not in keys
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-003.html" not in keys


# ---------------------------------------------------------------------------
# (b) Current page HTML is retained
# ---------------------------------------------------------------------------


@mock_aws
class TestCurrentPageHtmlRetained:
    def test_current_pages_not_deleted(self) -> None:
        """Dest page HTML that exists locally is retained."""
        _create_bucket()
        _put_s3_objects([
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
        ])

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_local_page_html(
                dist_dir,
                "data/tei/MS-ADD-03975",
                ["MS-ADD-03975-001.html", "MS-ADD-03975-002.html"],
            )
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html" in keys
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html" in keys


# ---------------------------------------------------------------------------
# (c) Empty local build deletes all dest page HTML for item
# ---------------------------------------------------------------------------


@mock_aws
class TestEmptyLocalDeletesAll:
    def test_no_local_pages_deletes_all_dest(self) -> None:
        """When no local page HTML exists, all dest page HTML for item is deleted."""
        _create_bucket()
        _put_s3_objects([
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
        ])

        with tempfile.TemporaryDirectory() as dist_dir:
            # No local page HTML created
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        assert len(keys) == 0


# ---------------------------------------------------------------------------
# (d) Page HTML for other items is not deleted
# ---------------------------------------------------------------------------


@mock_aws
class TestOtherItemsUnaffected:
    def test_other_item_pages_not_deleted(self) -> None:
        """Page HTML for a different item is not touched."""
        _create_bucket()
        _put_s3_objects([
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
            "html/data/tei/OTHER-ITEM/OTHER-ITEM-001.html",
            "html/data/tei/OTHER-ITEM/OTHER-ITEM-002.html",
        ])

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_local_page_html(
                dist_dir,
                "data/tei/MS-ADD-03975",
                ["MS-ADD-03975-001.html"],
            )
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        # Our stale page deleted
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html" not in keys
        # Other item untouched
        assert "html/data/tei/OTHER-ITEM/OTHER-ITEM-001.html" in keys
        assert "html/data/tei/OTHER-ITEM/OTHER-ITEM-002.html" in keys


# ---------------------------------------------------------------------------
# (d2) Stale unreleased page HTML is reconciled
# ---------------------------------------------------------------------------


@mock_aws
class TestUnreleasedPageHtmlReconciled:
    def test_stale_unreleased_pages_removed(self) -> None:
        """Stale page HTML under unreleased/html/ is deleted; current retained."""
        _create_bucket()
        _put_s3_objects([
            "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
            "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-003.html",
        ])

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_local_page_html(
                dist_dir,
                "data/tei/MS-ADD-03975",
                ["MS-ADD-03975-001.html"],
                location_prefix="unreleased/",
            )
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        assert "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html" in keys
        assert "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html" not in keys
        assert "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-003.html" not in keys

    def test_released_and_unreleased_reconciled_together(self) -> None:
        """A single call reconciles both locations independently."""
        _create_bucket()
        _put_s3_objects([
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
            "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
        ])

        with tempfile.TemporaryDirectory() as dist_dir:
            # Released keeps page 1; unreleased keeps page 2.
            _create_local_page_html(
                dist_dir, "data/tei/MS-ADD-03975", ["MS-ADD-03975-001.html"]
            )
            _create_local_page_html(
                dist_dir,
                "data/tei/MS-ADD-03975",
                ["MS-ADD-03975-002.html"],
                location_prefix="unreleased/",
            )
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html" in keys
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html" not in keys
        assert "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html" not in keys
        assert "unreleased/html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html" in keys


# ---------------------------------------------------------------------------
# (d3) Stale page XML is reconciled (released and unreleased)
# ---------------------------------------------------------------------------


@mock_aws
class TestStalePageXmlReconciled:
    def test_stale_page_xml_removed(self) -> None:
        """Dest page XML not in local build is deleted; current retained."""
        _create_bucket()
        _put_s3_objects([
            "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-001.xml",
            "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-002.xml",
            "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-003.xml",
        ])

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_local_page_xml(
                dist_dir,
                "items/data/tei/MS-ADD-03975",
                ["MS-ADD-03975-001.xml"],
            )
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        assert "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-001.xml" in keys
        assert "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-002.xml" not in keys
        assert "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-003.xml" not in keys

    def test_stale_unreleased_page_xml_removed(self) -> None:
        """Stale page XML under unreleased/page-xml/ is deleted; current retained."""
        _create_bucket()
        _put_s3_objects([
            "unreleased/page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-001.xml",
            "unreleased/page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-002.xml",
        ])

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_local_page_xml(
                dist_dir,
                "items/data/tei/MS-ADD-03975",
                ["MS-ADD-03975-001.xml"],
                location_prefix="unreleased/",
            )
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        assert "unreleased/page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-001.xml" in keys
        assert (
            "unreleased/page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-002.xml"
            not in keys
        )

    def test_html_and_page_xml_reconciled_in_one_call(self) -> None:
        """A single call reconciles both per-page families together."""
        _create_bucket()
        _put_s3_objects([
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
            "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-001.xml",
            "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-002.xml",
        ])

        with tempfile.TemporaryDirectory() as dist_dir:
            _create_local_page_html(
                dist_dir, "data/tei/MS-ADD-03975", ["MS-ADD-03975-001.html"]
            )
            _create_local_page_xml(
                dist_dir, "items/data/tei/MS-ADD-03975", ["MS-ADD-03975-001.xml"]
            )
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html" in keys
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html" not in keys
        assert "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-001.xml" in keys
        assert "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-002.xml" not in keys


# ---------------------------------------------------------------------------
# (e) Per-item single-file outputs are not deleted
# ---------------------------------------------------------------------------


@mock_aws
class TestSingleFileOutputsUnaffected:
    def test_single_file_outputs_not_deleted(self) -> None:
        """Per-item single-file outputs remain untouched; per-page ones reconcile."""
        _create_bucket()
        single_file_keys = [
            "json/MS-ADD-03975.json",
            "solr-json/MS-ADD-03975.json",
            "dp-json/MS-ADD-03975.json",
            "core-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975.xml",
            "items/data/tei/MS-ADD-03975/MS-ADD-03975.xml",
        ]
        _put_s3_objects(single_file_keys)
        _put_s3_objects([
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-001.xml",
        ])

        with tempfile.TemporaryDirectory() as dist_dir:
            # No local per-page files — all page HTML and page XML should delete
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        # Per-page outputs deleted
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html" not in keys
        assert "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-001.xml" not in keys
        # Per-item single-file outputs remain
        for k in single_file_keys:
            assert k in keys


# ---------------------------------------------------------------------------
# (f) Reconciliation uses full local set, not just uploaded subset
# ---------------------------------------------------------------------------


@mock_aws
class TestReconciliationUsesFullLocalSet:
    def test_skipped_upload_file_not_deleted(self) -> None:
        """A file present locally but skipped during upload is not deleted."""
        _create_bucket()
        s3 = boto3.client("s3", region_name="eu-west-1")

        content_1 = b"<html>page1</html>"

        # Pre-populate dest with page 1 (matching content) and page 2 (stale)
        s3.put_object(
            Bucket=BUCKET,
            Key="html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            Body=content_1,
        )
        s3.put_object(
            Bucket=BUCKET,
            Key="html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
            Body=b"<html>old-page2</html>",
        )
        # Page 3 exists on dest but not locally — stale
        s3.put_object(
            Bucket=BUCKET,
            Key="html/data/tei/MS-ADD-03975/MS-ADD-03975-003.html",
            Body=b"<html>stale</html>",
        )

        with tempfile.TemporaryDirectory() as dist_dir:
            # Local has pages 1 and 2 (page 1 unchanged, page 2 updated)
            _create_local_page_html(
                dist_dir,
                "data/tei/MS-ADD-03975",
                ["MS-ADD-03975-001.html", "MS-ADD-03975-002.html"],
            )
            reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

        keys = _list_s3_keys()
        # Pages 1 and 2 retained (even if page 1 wasn't re-uploaded)
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html" in keys
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html" in keys
        # Page 3 deleted (stale)
        assert "html/data/tei/MS-ADD-03975/MS-ADD-03975-003.html" not in keys


# ---------------------------------------------------------------------------
# (g) Reconciliation does not run if upload fails
# ---------------------------------------------------------------------------


class TestReconciliationSkippedOnUploadFailure:
    @patch("handler.reconcile_stale_page_outputs")
    @patch("handler.upload_dist", side_effect=TransientError("upload boom"))
    @patch("handler.run_ant")
    @patch("handler.download_file")
    @patch("handler.clean_dist")
    @patch("handler.clean_source_workspace")
    def test_no_reconciliation_when_upload_fails(
        self,
        mock_clean_src: MagicMock,
        mock_clean_dist: MagicMock,
        mock_download: MagicMock,
        mock_ant: MagicMock,
        mock_upload: MagicMock,
        mock_reconcile: MagicMock,
        env_config: None,
    ) -> None:
        from handler import handler

        body = {
            "Records": [
                {
                    "eventName": "ObjectCreated:Put",
                    "s3": {
                        "bucket": {"name": "src-bucket"},
                        "object": {"key": TEI_FILE},
                    },
                }
            ]
        }
        record = {"messageId": "msg-1", "body": json.dumps(body)}
        event: dict[str, Any] = {"Records": [record]}

        with patch("handler.setup_workspace"):
            result = handler(event, None)

        mock_reconcile.assert_not_called()
        assert result == {"batchItemFailures": [{"itemIdentifier": "msg-1"}]}


# ---------------------------------------------------------------------------
# (h) S3 failure during reconciliation is transient
# ---------------------------------------------------------------------------


@mock_aws
class TestReconciliationS3FailureIsTransient:
    def test_list_failure_raises_transient(self) -> None:
        """ClientError during S3 list is wrapped in TransientError."""
        _create_bucket()

        with (
            tempfile.TemporaryDirectory() as dist_dir,
            patch("s3_ops._s3_client") as mock_client_fn,
        ):
            mock_s3 = MagicMock()
            mock_client_fn.return_value = mock_s3
            mock_paginator = MagicMock()
            mock_s3.get_paginator.return_value = mock_paginator
            mock_paginator.paginate.side_effect = ClientError(
                {"Error": {"Code": "InternalError", "Message": "boom"}},
                "ListObjectsV2",
            )

            with pytest.raises(TransientError, match="reconciliation failed"):
                reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)

    def test_delete_failure_raises_transient(self) -> None:
        """ClientError during S3 delete is wrapped in TransientError."""
        _create_bucket()
        _put_s3_objects([
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
        ])

        # No local pages — all dest pages are stale
        with (
            tempfile.TemporaryDirectory() as dist_dir,
            patch("s3_ops._s3_client") as mock_client_fn,
        ):
            real_s3 = boto3.client("s3", region_name="eu-west-1")
            mock_s3 = MagicMock()
            mock_client_fn.return_value = mock_s3
            # Let paginate work with real data
            mock_s3.get_paginator.return_value = real_s3.get_paginator("list_objects_v2")
            mock_s3.delete_objects.side_effect = ClientError(
                {"Error": {"Code": "InternalError", "Message": "boom"}},
                "DeleteObjects",
            )

            with pytest.raises(TransientError, match="reconciliation failed"):
                reconcile_stale_page_outputs(dist_dir, BUCKET, TEI_FILE)


# ---------------------------------------------------------------------------
# (i) Existing ObjectRemoved full-delete behaviour unchanged
# ---------------------------------------------------------------------------


@mock_aws
class TestObjectRemovedUnchanged:
    def test_object_removed_still_deletes_all_outputs(self) -> None:
        """ObjectRemoved path uses delete_outputs, not reconciliation."""
        from s3_ops import delete_outputs

        s3 = boto3.client("s3", region_name="eu-west-1")
        s3.create_bucket(
            Bucket=BUCKET,
            CreateBucketConfiguration={"LocationConstraint": "eu-west-1"},
        )

        all_keys = [
            "json/MS-ADD-03975.json",
            "solr-json/MS-ADD-03975.json",
            "dp-json/MS-ADD-03975.json",
            "core-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975.xml",
            "items/data/tei/MS-ADD-03975/MS-ADD-03975.xml",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-001.html",
            "html/data/tei/MS-ADD-03975/MS-ADD-03975-002.html",
            "page-xml/items/data/tei/MS-ADD-03975/MS-ADD-03975-001.xml",
        ]
        for key in all_keys:
            s3.put_object(Bucket=BUCKET, Key=key, Body=b"data")

        delete_outputs(BUCKET, TEI_FILE)

        resp = s3.list_objects_v2(Bucket=BUCKET)
        assert resp.get("KeyCount", 0) == 0
