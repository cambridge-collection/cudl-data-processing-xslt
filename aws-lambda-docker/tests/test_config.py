"""Tests for config.py — defaults, env loading, validation."""

from __future__ import annotations

import pytest

from config import Config
from exceptions import ConfigError


class TestConfigFromEnv:
    def test_defaults_when_no_env(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("AWS_OUTPUT_BUCKET", raising=False)
        monkeypatch.delenv("SEARCH_HOST", raising=False)
        monkeypatch.delenv("SEARCH_PORT", raising=False)
        monkeypatch.delenv("SEARCH_COLLECTION_PATH", raising=False)
        monkeypatch.delenv("ANT_TARGET", raising=False)
        monkeypatch.delenv("SKIP_COPY_TEI_WEB_ASSETS", raising=False)
        monkeypatch.delenv("LAMBDA_TIMEOUT_MARGIN_MS", raising=False)
        monkeypatch.delenv("ENABLE_SHA_METADATA", raising=False)
        monkeypatch.delenv("ENABLE_RELEASE_STATUS_METADATA", raising=False)

        cfg = Config.from_env()

        assert cfg.aws_output_bucket == ""
        assert cfg.search_host == ""
        assert cfg.search_port == ""
        assert cfg.search_collection_path == "collections"
        assert cfg.ant_target == "full"
        assert cfg.skip_copy_tei_web_assets == "false"
        assert cfg.lambda_timeout_margin_ms == 5000
        assert cfg.enable_sha_metadata is False
        assert cfg.enable_release_status_metadata is False

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
        with pytest.raises(ConfigError, match="AWS_OUTPUT_BUCKET"):
            Config.from_env().validate_for_aws()

    def test_validate_raises_missing_host(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("AWS_OUTPUT_BUCKET", "bucket")
        monkeypatch.delenv("SEARCH_HOST", raising=False)
        with pytest.raises(ConfigError, match="SEARCH_HOST"):
            Config.from_env().validate_for_aws()

    def test_validate_raises_both_missing(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("AWS_OUTPUT_BUCKET", raising=False)
        monkeypatch.delenv("SEARCH_HOST", raising=False)
        with pytest.raises(ConfigError, match="AWS_OUTPUT_BUCKET.*SEARCH_HOST"):
            Config.from_env().validate_for_aws()

    def test_reads_lambda_timeout_margin_ms(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("AWS_OUTPUT_BUCKET", "b")
        monkeypatch.setenv("SEARCH_HOST", "h")
        monkeypatch.setenv("LAMBDA_TIMEOUT_MARGIN_MS", "10000")

        cfg = Config.from_env()

        assert cfg.lambda_timeout_margin_ms == 10000

    def test_reads_sha_and_release_status_flags(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setenv("ENABLE_SHA_METADATA", "true")
        monkeypatch.setenv("ENABLE_RELEASE_STATUS_METADATA", "True")

        cfg = Config.from_env()

        assert cfg.enable_sha_metadata is True
        assert cfg.enable_release_status_metadata is True

    def test_frozen(self) -> None:
        cfg = Config(
            aws_output_bucket="b",
            search_host="h",
            search_port="p",
            search_collection_path="c",
            ant_target="full",
            skip_copy_tei_web_assets="false",
            emit_emf_metrics=False,
            lambda_timeout_margin_ms=5000,
            enable_sha_metadata=False,
            enable_release_status_metadata=False,
        )
        with pytest.raises(AttributeError):
            cfg.aws_output_bucket = "other"  # type: ignore[misc]
