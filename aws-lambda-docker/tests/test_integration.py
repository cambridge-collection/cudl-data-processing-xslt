"""Docker integration test — builds and runs the full local pipeline, verifies output.

Requires Docker to be running. Skipped automatically if Docker is unavailable.
Run with: cd aws-lambda-docker && python -m pytest tests/ -v -m integration
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DIST_DIR = REPO_ROOT / "dist"
DATA_DIR = REPO_ROOT / "data"
TEI_FILE = "items/data/tei/MS-ADD-03975/MS-ADD-03975.xml"
ITEM_ID = "MS-ADD-03975"
COMPOSE_FILE = "docker-compose-local.yml"


def _docker_available() -> bool:
    """Check if Docker daemon is reachable."""
    try:
        subprocess.run(
            ["docker", "info"],
            capture_output=True,
            timeout=10,
        )
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _source_tei_exists() -> bool:
    return (DATA_DIR / TEI_FILE).exists()


pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(not _docker_available(), reason="Docker not available"),
    pytest.mark.skipif(not _source_tei_exists(), reason=f"TEI source missing: {TEI_FILE}"),
]


@pytest.fixture(scope="module")
def pipeline_run() -> dict[str, Any]:
    """Build and run the full pipeline once for all tests in this module."""
    # Clean dist/ so we only see output from this run
    if DIST_DIR.exists():
        shutil.rmtree(DIST_DIR)
    DIST_DIR.mkdir()

    env = {**os.environ, "TEI_FILE": TEI_FILE}

    result = subprocess.run(
        [
            "docker",
            "compose",
            "-f",
            COMPOSE_FILE,
            "up",
            "--build",
            "--abort-on-container-exit",
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=300,
        env=env,
    )

    yield {
        "returncode": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }

    # Teardown: stop containers and remove volumes
    subprocess.run(
        ["docker", "compose", "-f", COMPOSE_FILE, "down", "-v"],
        cwd=REPO_ROOT,
        capture_output=True,
    )


class TestPipelineExecution:
    """Verify the container runs and exits cleanly."""

    def test_exit_code_zero(self, pipeline_run: dict[str, Any]) -> None:
        assert pipeline_run["returncode"] == 0, (
            f"Container failed (exit {pipeline_run['returncode']}):\n"
            f"{pipeline_run['stderr'][-3000:]}"
        )


class TestJsonOutputs:
    """Verify JSON output files are valid."""

    def test_json_exists_and_valid(self, pipeline_run: dict[str, Any]) -> None:
        path = DIST_DIR / "json" / f"{ITEM_ID}.json"
        assert path.exists(), f"Missing {path.relative_to(REPO_ROOT)}"
        data = json.loads(path.read_text())
        assert isinstance(data, dict)

    def test_dp_json_exists_and_valid(self, pipeline_run: dict[str, Any]) -> None:
        path = DIST_DIR / "dp-json" / f"{ITEM_ID}.json"
        assert path.exists(), f"Missing {path.relative_to(REPO_ROOT)}"
        data = json.loads(path.read_text())
        assert isinstance(data, dict)

    def test_solr_json_exists_and_valid(self, pipeline_run: dict[str, Any]) -> None:
        path = DIST_DIR / "solr-json" / f"{ITEM_ID}.json"
        assert path.exists(), f"Missing {path.relative_to(REPO_ROOT)}"
        data = json.loads(path.read_text())
        assert isinstance(data, dict)


class TestTeiCopy:
    """Verify the source TEI is copied to dist/items/."""

    def test_tei_copied(self, pipeline_run: dict[str, Any]) -> None:
        path = DIST_DIR / TEI_FILE
        assert path.exists(), f"Missing {path.relative_to(REPO_ROOT)}"
        content = path.read_text()
        assert "<TEI" in content or "<tei" in content.lower()


class TestHtmlOutput:
    """Verify HTML page outputs are generated."""

    def test_html_pages_created(self, pipeline_run: dict[str, Any]) -> None:
        html_dir = DIST_DIR / "html" / "data" / "tei" / ITEM_ID
        assert html_dir.exists(), f"Missing HTML output dir: {html_dir.relative_to(REPO_ROOT)}"
        html_files = sorted(html_dir.glob("*.html"))
        assert len(html_files) >= 1, "No HTML pages generated"

    def test_html_pages_non_empty(self, pipeline_run: dict[str, Any]) -> None:
        html_dir = DIST_DIR / "html" / "data" / "tei" / ITEM_ID
        for html_file in html_dir.glob("*.html"):
            size = html_file.stat().st_size
            assert size > 100, f"{html_file.name} suspiciously small ({size} bytes)"


class TestJsonContent:
    """Spot-check JSON content for expected fields."""

    def test_json_has_item_id(self, pipeline_run: dict[str, Any]) -> None:
        path = DIST_DIR / "json" / f"{ITEM_ID}.json"
        if not path.exists():
            pytest.skip("JSON output missing (covered by TestJsonOutputs)")
        # Validate JSON is parseable, then check content
        raw = path.read_text()
        json.loads(raw)
        assert ITEM_ID in raw, f"{ITEM_ID} not found in JSON output"

    def test_dp_json_has_pages(self, pipeline_run: dict[str, Any]) -> None:
        path = DIST_DIR / "dp-json" / f"{ITEM_ID}.json"
        if not path.exists():
            pytest.skip("dp-json output missing (covered by TestJsonOutputs)")
        data = json.loads(path.read_text())
        # dp-json typically contains page-level data
        assert len(data) > 0, "dp-json is empty"
