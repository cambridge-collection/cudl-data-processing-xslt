"""Configuration from environment variables."""

from __future__ import annotations

import os
from dataclasses import dataclass

from exceptions import ConfigError

# Paths
OPT_CDCP = "/opt/cdcp"
TMP_CDCP = "/tmp/opt/cdcp"
ANT_BIN = "/opt/ant/bin/ant"
BUILDFILE = f"{TMP_CDCP}/bin/build.xml"
SOURCE_DIR = f"{TMP_CDCP}/cudl-data-source"
DIST_DIR = f"{TMP_CDCP}/dist"
DIST_PENDING_DIR = f"{TMP_CDCP}/dist-pending"


@dataclass(frozen=True)
class Config:
    """Processing configuration from environment variables."""

    aws_output_bucket: str
    search_host: str
    search_port: str
    search_collection_path: str
    ant_target: str
    skip_copy_tei_web_assets: str
    emit_emf_metrics: bool
    lambda_timeout_margin_ms: int
    enable_sha_metadata: bool
    enable_release_status_metadata: bool

    @classmethod
    def from_env(cls) -> Config:
        return cls(
            aws_output_bucket=os.environ.get("AWS_OUTPUT_BUCKET", ""),
            search_host=os.environ.get("SEARCH_HOST", ""),
            search_port=os.environ.get("SEARCH_PORT", ""),
            search_collection_path=os.environ.get("SEARCH_COLLECTION_PATH", "collections"),
            ant_target=os.environ.get("ANT_TARGET", "full"),
            skip_copy_tei_web_assets=os.environ.get("SKIP_COPY_TEI_WEB_ASSETS", "false"),
            emit_emf_metrics=os.environ.get("EMIT_EMF_METRICS", "false").lower() == "true",
            lambda_timeout_margin_ms=int(
                os.environ.get("LAMBDA_TIMEOUT_MARGIN_MS", "5000")
            ),
            enable_sha_metadata=os.environ.get(
                "ENABLE_SHA_METADATA", "false"
            ).lower()
            == "true",
            enable_release_status_metadata=os.environ.get(
                "ENABLE_RELEASE_STATUS_METADATA", "false"
            ).lower()
            == "true",
        )

    def validate_for_aws(self) -> None:
        """Validate required config for AWS Lambda processing."""
        missing = []
        if not self.aws_output_bucket:
            missing.append("AWS_OUTPUT_BUCKET")
        if not self.search_host:
            missing.append("SEARCH_HOST")
        if missing:
            raise ConfigError(f"Missing required environment variables: {', '.join(missing)}")
