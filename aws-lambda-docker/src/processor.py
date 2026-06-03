"""Core processing: workspace management and Ant invocation."""

from __future__ import annotations

import logging
import os
import re
import shutil
import subprocess

from config import (
    ANT_BIN,
    BUILDFILE,
    DIST_DIR,
    DIST_PENDING_DIR,
    OPT_CDCP,
    SOURCE_DIR,
    TMP_CDCP,
    Config,
)
from exceptions import PermanentError, TransientError

logger = logging.getLogger(__name__)

# Patterns in Ant/Saxon stderr that indicate transient (retryable) failures.
_TRANSIENT_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"Search API not responding", re.IGNORECASE),
    re.compile(r"Connection refused", re.IGNORECASE),
    re.compile(r"Connection timed out", re.IGNORECASE),
    re.compile(r"UnknownHostException", re.IGNORECASE),
    re.compile(r"HTTP error", re.IGNORECASE),
    re.compile(r"\b503\b"),
    re.compile(r"\b429\b"),
]

# Patterns that indicate permanent (non-retryable) failures.
_PERMANENT_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"not well-formed", re.IGNORECASE),
    re.compile(r"Content is not allowed in prolog", re.IGNORECASE),
    re.compile(r"invalid item-collections JSON", re.IGNORECASE),
    re.compile(r"\bXTDE\d+"),  # Saxon dynamic errors
    re.compile(r"\bXPTY\d+"),  # Saxon type errors
    re.compile(r"\bXTTE\d+"),  # Saxon type errors (transforms)
    re.compile(r"\bFORG\d+"),  # Saxon function/operator errors
    re.compile(r"\bXPST\d+"),  # Saxon static errors
    re.compile(r"AccessDenied", re.IGNORECASE),
]


def _classify_error(error_lines: list[str]) -> type[TransientError] | type[PermanentError]:
    """Classify Ant build failure as transient or permanent from stderr.

    Transient wins if any line matches a transient pattern, because a
    service being down can cause cascading Saxon errors that look permanent.
    """
    for line in error_lines:
        for pattern in _TRANSIENT_PATTERNS:
            if pattern.search(line):
                return TransientError
    for line in error_lines:
        for pattern in _PERMANENT_PATTERNS:
            if pattern.search(line):
                return PermanentError
    # Default: treat unknown Ant failures as permanent to avoid infinite retries.
    return PermanentError

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
            shutil.copytree(src, dst)


def clean_source_workspace() -> None:
    """Remove and recreate the source workspace."""
    if os.path.exists(SOURCE_DIR):
        shutil.rmtree(SOURCE_DIR)
    os.makedirs(SOURCE_DIR, exist_ok=True)


def clean_dist() -> None:
    """Remove and recreate the dist and dist-pending directories."""
    for d in (DIST_DIR, DIST_PENDING_DIR):
        if os.path.exists(d):
            shutil.rmtree(d)
    os.makedirs(DIST_DIR, exist_ok=True)
    os.makedirs(f"{DIST_PENDING_DIR}/collection-xml", exist_ok=True)


def run_ant(config: Config, tei_file: str, *, stream_stdout: bool = False) -> None:
    """Run the Ant build for a TEI file.

    Always sets ENVIRONMENT=local so Ant outputs to dist/ locally.
    S3 upload is handled separately by Python/boto3.

    When stream_stdout is True, Ant's stdout goes directly to the
    terminal for real-time progress. Stderr is still captured for
    error classification.
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
        "SEARCH_HOST": config.search_host,
        "SEARCH_COLLECTION_PATH": config.search_collection_path,
        "SEARCH_PORT": config.search_port,
        "SKIP_COPY_TEI_WEB_ASSETS": config.skip_copy_tei_web_assets,
    }

    stdout_arg = None if stream_stdout else subprocess.PIPE
    result = subprocess.run(cmd, env=env, stdout=stdout_arg, stderr=subprocess.PIPE, text=True)

    if not stream_stdout:
        for line in result.stdout.splitlines():
            stripped = line.strip()
            if "[echo]" in stripped:
                msg = stripped.split("[echo]", 1)[1].strip()
                logger.info(msg, extra={"source": "ant"})
            elif stripped:
                logger.debug(stripped, extra={"source": "ant"})

    stderr_noise = {"BUILD FAILED", "Total time:"}
    error_lines: list[str] = []
    if result.stderr:
        for line in result.stderr.splitlines():
            stripped = line.strip()
            if stripped and not any(stripped.startswith(n) for n in stderr_noise):
                error_lines.append(stripped)
                logger.debug(stripped, extra={"source": "ant"})

    if result.returncode != 0:
        error_cls = _classify_error(error_lines)
        build_context = {
            "tei_file": tei_file,
            "target": config.ant_target,
            "exit_code": result.returncode,
            "stderr_lines": error_lines,
            "cmd": " ".join(cmd),
            "error_type": error_cls.__name__,
        }
        logger.error("Ant build failed", extra={"context": build_context})
        # stderr detail is captured structurally in build_context above, so the
        # exception message stays concise to avoid re-embedding it in the
        # handler's traceback log.
        raise error_cls(
            f"Ant build failed for {tei_file} (exit {result.returncode})"
        )
