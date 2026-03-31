"""Local CLI entry point for TEI processing (replaces local.sh)."""

from __future__ import annotations

import logging
import os
import sys

from config import Config
from processor import run_ant, setup_workspace

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


def main() -> None:
    tei_file = os.environ.get("TEI_FILE", "")
    if not tei_file:
        print("ERROR: TEI_FILE environment variable not set", file=sys.stderr)
        sys.exit(1)

    config = Config.from_env()
    logger.info("Processing %s (target: %s)", tei_file, config.ant_target)

    setup_workspace()
    run_ant(config, tei_file)

    logger.info("Processing complete. Output in dist/")


if __name__ == "__main__":
    main()
