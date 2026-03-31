"""Tests for processor.py — Ant invocation command and env."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from config import ANT_BIN, BUILDFILE, Config
from processor import run_ant


@pytest.fixture()
def config() -> Config:
    return Config(
        aws_output_bucket="test-bucket",
        search_host="solr.local",
        search_port="8983",
        search_collection_path="collections",
        ant_target="full",
        skip_copy_tei_web_assets="false",
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

    @patch("processor.subprocess.run")
    def test_nonzero_exit_raises(self, mock_run: MagicMock, config: Config) -> None:
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="BUILD FAILED")

        with pytest.raises(RuntimeError, match="Ant build failed"):
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
        )
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        run_ant(config, TEI_FILE)

        cmd = mock_run.call_args[0][0]
        assert cmd[3] == "html-only"
