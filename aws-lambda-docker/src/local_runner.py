"""Local CLI entry point for TEI processing (replaces local.sh)."""

from __future__ import annotations

import logging
import os
import sys

from config import Config
from logging_config import configure_logging
from processor import run_ant, setup_workspace

configure_logging()
logger = logging.getLogger(__name__)


def main() -> None:
    tei_file = os.environ.get("TEI_FILE", "")
    if not tei_file:
        print("ERROR: TEI_FILE environment variable not set", file=sys.stderr)
        sys.exit(1)

    config = Config.from_env()
    logger.info("Processing %s (target: %s)", tei_file, config.ant_target)

    setup_workspace()
    stream = logging.getLogger().isEnabledFor(logging.INFO)
    run_ant(config, tei_file, stream_stdout=stream)

    logger.info("Processing complete. Output in dist/")


if __name__ == "__main__":
    main()
