"""Tests for tei.py — TEI release-status resolution."""

from __future__ import annotations

import subprocess
from unittest.mock import patch

import pytest

from exceptions import PermanentError
from tei import resolve_release_status


def _make_result(
    stdout: str = "", stderr: str = "", returncode: int = 0
) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(
        args=[], returncode=returncode, stdout=stdout, stderr=stderr
    )


class TestResolveReleaseStatus:
    """(i) released/draft resolution and (j) error handling."""

    @patch("tei.subprocess.run")
    def test_released_when_change_status_released(self, mock_run: object) -> None:
        mock_run.return_value = _make_result(stdout="released\n")  # type: ignore[union-attr]
        assert resolve_release_status("/tmp/test.xml") == "released"

    @patch("tei.subprocess.run")
    def test_draft_when_no_change_status_released(self, mock_run: object) -> None:
        mock_run.return_value = _make_result(stdout="draft\n")  # type: ignore[union-attr]
        assert resolve_release_status("/tmp/test.xml") == "draft"

    @patch("tei.subprocess.run")
    def test_malformed_xml_raises_permanent(self, mock_run: object) -> None:
        mock_run.return_value = _make_result(  # type: ignore[union-attr]
            returncode=2,
            stderr="Error on line 3: not well-formed (invalid token)",
        )
        with pytest.raises(PermanentError, match="Saxon XPath evaluation failed"):
            resolve_release_status("/tmp/bad.xml")

    @patch("tei.subprocess.run")
    def test_missing_tei_root_raises_permanent(self, mock_run: object) -> None:
        mock_run.return_value = _make_result(stdout="NOT_TEI_ROOT\n")  # type: ignore[union-attr]
        with pytest.raises(PermanentError, match="lacks expected TEI namespace root"):
            resolve_release_status("/tmp/not-tei.xml")

    @patch("tei.subprocess.run")
    def test_unexpected_output_raises_permanent(self, mock_run: object) -> None:
        mock_run.return_value = _make_result(stdout="something-else\n")  # type: ignore[union-attr]
        with pytest.raises(PermanentError, match="Unexpected Saxon output"):
            resolve_release_status("/tmp/weird.xml")

    @patch("tei.subprocess.run")
    def test_passes_correct_command(self, mock_run: object) -> None:
        mock_run.return_value = _make_result(stdout="draft\n")  # type: ignore[union-attr]
        resolve_release_status("/tmp/items/data/tei/MS-ADD-03975/MS-ADD-03975.xml")
        args = mock_run.call_args  # type: ignore[union-attr]
        cmd = args[0][0]
        assert cmd[0] == "java"
        assert "-cp" in cmd
        assert "net.sf.saxon.Query" in cmd
        assert any(
            a.startswith("-s:/tmp/items/data/tei/MS-ADD-03975/MS-ADD-03975.xml")
            for a in cmd
        )
