"""Tests for processor.py — Ant invocation command and env."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from config import ANT_BIN, BUILDFILE, Config
from exceptions import PermanentError, TransientError
from processor import _classify_error, run_ant


@pytest.fixture()
def config() -> Config:
    return Config(
        aws_output_bucket="test-bucket",
        search_host="solr.local",
        search_port="8983",
        search_collection_path="collections",
        ant_target="full",
        skip_copy_tei_web_assets="false",
        enable_unreleased_partition="false",
        emit_emf_metrics=False,
        lambda_timeout_margin_ms=5000,
        enable_sha_metadata=False,
        enable_release_status_metadata=False,
    )


TEI_FILE = "items/data/tei/MS-ADD-03975/MS-ADD-03975.xml"


class TestRunAnt:
    @patch("processor.subprocess.run")
    def test_command_structure(self, mock_run: MagicMock, config: Config) -> None:
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        run_ant(config, TEI_FILE)

        mock_run.assert_called_once()
        cmd = mock_run.call_args[0][0]
        assert cmd[0] == ANT_BIN
        assert cmd[1:3] == ["-buildfile", BUILDFILE]
        assert cmd[3] == "full"  # ant_target
        assert cmd[4] == f"-Dfiles-to-process={TEI_FILE}"

    @patch("processor.subprocess.run")
    def test_environment_forced_local(self, mock_run: MagicMock, config: Config) -> None:
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        run_ant(config, TEI_FILE)

        env = mock_run.call_args[1]["env"]
        assert env["ENVIRONMENT"] == "local"

    @patch("processor.subprocess.run")
    def test_config_values_in_env(self, mock_run: MagicMock, config: Config) -> None:
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        run_ant(config, TEI_FILE)

        env = mock_run.call_args[1]["env"]
        assert env["SEARCH_COLLECTION_PATH"] == "collections"
        assert env["SEARCH_PORT"] == "8983"
        assert env["SKIP_COPY_TEI_WEB_ASSETS"] == "false"
        assert env["ENABLE_UNRELEASED_PARTITION"] == "false"

    @patch("processor.subprocess.run")
    def test_nonzero_exit_raises_permanent_by_default(
        self, mock_run: MagicMock, config: Config
    ) -> None:
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="BUILD FAILED")

        with pytest.raises(PermanentError, match="Ant build failed"):
            run_ant(config, TEI_FILE)

    @patch("processor.subprocess.run")
    def test_nonzero_exit_raises_transient_for_search_api(
        self, mock_run: MagicMock, config: Config
    ) -> None:
        mock_run.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr="ERROR: Search API not responding for http://solr:8983/items/X/collections",
        )

        with pytest.raises(TransientError, match="Ant build failed"):
            run_ant(config, TEI_FILE)

    @patch("processor.subprocess.run")
    def test_nonzero_exit_raises_permanent_for_malformed_xml(
        self, mock_run: MagicMock, config: Config
    ) -> None:
        mock_run.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr="Fatal error: not well-formed (invalid token)",
        )

        with pytest.raises(PermanentError, match="Ant build failed"):
            run_ant(config, TEI_FILE)

    @patch("processor.subprocess.run")
    def test_custom_ant_target(self, mock_run: MagicMock) -> None:
        config = Config(
            aws_output_bucket="b",
            search_host="h",
            search_port="p",
            search_collection_path="c",
            ant_target="html-only",
            skip_copy_tei_web_assets="true",
            enable_unreleased_partition="false",
            emit_emf_metrics=False,
            lambda_timeout_margin_ms=5000,
            enable_sha_metadata=False,
            enable_release_status_metadata=False,
        )
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        run_ant(config, TEI_FILE)

        cmd = mock_run.call_args[0][0]
        assert cmd[3] == "html-only"


class TestClassifyError:
    """Unit tests for stderr pattern classification."""

    @pytest.mark.parametrize(
        "line",
        [
            "ERROR: Search API not responding for http://solr:8983/items/X/collections",
            "java.net.ConnectException: Connection refused",
            "java.net.ConnectException: Connection timed out",
            "java.net.UnknownHostException: solr.local",
            "HTTP error 503",
            "HTTP error 429",
        ],
    )
    def test_transient_patterns(self, line: str) -> None:
        assert _classify_error([line]) is TransientError

    @pytest.mark.parametrize(
        "line",
        [
            "Fatal error: not well-formed (invalid token)",
            "Content is not allowed in prolog",
            "ERROR: Response does not appear to be valid item-collections JSON response",
            "XTDE0160: Saxon error in template",
            "XPTY0004: Required item type of first operand",
            "XTTE0570: Required item type of value",
            "FORG0001: Cannot convert",
            "XPST0017: Static error in XPath",
            "S3 AccessDenied for bucket",
        ],
    )
    def test_permanent_patterns(self, line: str) -> None:
        assert _classify_error([line]) is PermanentError

    def test_unknown_error_defaults_to_permanent(self) -> None:
        assert _classify_error(["something completely unexpected"]) is PermanentError

    def test_empty_stderr_defaults_to_permanent(self) -> None:
        assert _classify_error([]) is PermanentError

    def test_transient_wins_over_permanent(self) -> None:
        """Transient signal takes priority — a downed service can cause Saxon errors."""
        lines = [
            "XTDE0160: Saxon error in template",
            "ERROR: Search API not responding for http://solr:8983/items/X/collections",
        ]
        assert _classify_error(lines) is TransientError
