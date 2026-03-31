"""Tests for config.py — defaults, env loading, validation."""

from __future__ import annotations

import pytest

from config import Config


class TestConfigFromEnv:
    def test_defaults_when_no_env(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("AWS_OUTPUT_BUCKET", raising=False)
        monkeypatch.delenv("SEARCH_HOST", raising=False)
        monkeypatch.delenv("SEARCH_PORT", raising=False)
        monkeypatch.delenv("SEARCH_COLLECTION_PATH", raising=False)
        monkeypatch.delenv("ANT_TARGET", raising=False)
        monkeypatch.delenv("SKIP_COPY_TEI_WEB_ASSETS", raising=False)

        cfg = Config.from_env()

        assert cfg.aws_output_bucket == ""
        assert cfg.search_host == ""
        assert cfg.search_port == ""
        assert cfg.search_collection_path == "collections"
        assert cfg.ant_target == "full"
        assert cfg.skip_copy_tei_web_assets == "false"

    def test_reads_env_vars(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("AWS_OUTPUT_BUCKET", "my-bucket")
        monkeypatch.setenv("SEARCH_HOST", "solr.example.com")
        monkeypatch.setenv("SEARCH_PORT", "8983")
        monkeypatch.setenv("SEARCH_COLLECTION_PATH", "custom/path")
        monkeypatch.setenv("ANT_TARGET", "html-only")
        monkeypatch.setenv("SKIP_COPY_TEI_WEB_ASSETS", "true")

        cfg = Config.from_env()

        assert cfg.aws_output_bucket == "my-bucket"
        assert cfg.search_host == "solr.example.com"
        assert cfg.search_port == "8983"
        assert cfg.search_collection_path == "custom/path"
        assert cfg.ant_target == "html-only"
        assert cfg.skip_copy_tei_web_assets == "true"


class TestConfigValidation:
    def test_validate_passes_when_all_set(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("AWS_OUTPUT_BUCKET", "bucket")
        monkeypatch.setenv("SEARCH_HOST", "host")
        Config.from_env().validate_for_aws()  # should not raise

    def test_validate_raises_missing_bucket(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("AWS_OUTPUT_BUCKET", raising=False)
        monkeypatch.setenv("SEARCH_HOST", "host")
        with pytest.raises(ValueError, match="AWS_OUTPUT_BUCKET"):
            Config.from_env().validate_for_aws()

    def test_validate_raises_missing_host(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("AWS_OUTPUT_BUCKET", "bucket")
        monkeypatch.delenv("SEARCH_HOST", raising=False)
        with pytest.raises(ValueError, match="SEARCH_HOST"):
            Config.from_env().validate_for_aws()

    def test_validate_raises_both_missing(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("AWS_OUTPUT_BUCKET", raising=False)
        monkeypatch.delenv("SEARCH_HOST", raising=False)
        with pytest.raises(ValueError, match="AWS_OUTPUT_BUCKET.*SEARCH_HOST"):
            Config.from_env().validate_for_aws()

    def test_frozen(self) -> None:
        cfg = Config(
            aws_output_bucket="b",
            search_host="h",
            search_port="p",
            search_collection_path="c",
            ant_target="full",
            skip_copy_tei_web_assets="false",
        )
        with pytest.raises(AttributeError):
            cfg.aws_output_bucket = "other"  # type: ignore[misc]
