"""Core processing: workspace management and Ant invocation."""

from __future__ import annotations

import logging
import os
import shutil
import subprocess

from config import ANT_BIN, BUILDFILE, DIST_DIR, OPT_CDCP, SOURCE_DIR, TMP_CDCP, Config

logger = logging.getLogger(__name__)

WORKSPACE_DIRS = [
    f"{TMP_CDCP}/dist",
    f"{TMP_CDCP}/dist-pending/collection-xml",
    f"{TMP_CDCP}/transcriptions",
    SOURCE_DIR,
]


def setup_workspace() -> None:
    """Create working directories and copy build files to /tmp."""
    for d in WORKSPACE_DIRS:
        os.makedirs(d, exist_ok=True)

    for subdir in ("bin", "xslt"):
        src = os.path.join(OPT_CDCP, subdir)
        dst = os.path.join(TMP_CDCP, subdir)
        if os.path.isdir(src) and not os.path.isdir(dst):
            logger.info("Copying %s to %s", src, dst)
            shutil.copytree(src, dst)


def clean_source_workspace() -> None:
    """Remove and recreate the source workspace."""
    if os.path.exists(SOURCE_DIR):
        shutil.rmtree(SOURCE_DIR)
    os.makedirs(SOURCE_DIR, exist_ok=True)


def clean_dist() -> None:
    """Remove and recreate the dist directory."""
    if os.path.exists(DIST_DIR):
        shutil.rmtree(DIST_DIR)
    os.makedirs(DIST_DIR, exist_ok=True)


def run_ant(config: Config, tei_file: str) -> None:
    """Run the Ant build for a TEI file.

    Always sets ENVIRONMENT=local so Ant outputs to dist/ locally.
    S3 upload is handled separately by Python/boto3.
    """
    cmd = [
        ANT_BIN,
        "-buildfile",
        BUILDFILE,
        config.ant_target,
        f"-Dfiles-to-process={tei_file}",
    ]
    logger.info("Running: %s", " ".join(cmd))

    # Force ENVIRONMENT=local so Ant uses _copy_to_dist (not _copy_to_s3).
    # Propagate config defaults for env vars that Ant reads.
    env = {
        **os.environ,
        "ENVIRONMENT": "local",
        "SEARCH_COLLECTION_PATH": config.search_collection_path,
        "SEARCH_PORT": config.search_port,
        "SKIP_COPY_TEI_WEB_ASSETS": config.skip_copy_tei_web_assets,
    }

    result = subprocess.run(cmd, env=env, capture_output=True, text=True)

    if result.stdout:
        logger.info("Ant stdout:\n%s", result.stdout)
    if result.stderr:
        logger.warning("Ant stderr:\n%s", result.stderr)

    if result.returncode != 0:
        raise RuntimeError(f"Ant build failed (exit code {result.returncode}):\n{result.stderr}")
