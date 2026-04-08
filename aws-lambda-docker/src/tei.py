"""TEI release-status resolution via Saxon XPath evaluation."""

from __future__ import annotations

import logging
import subprocess

from exceptions import PermanentError

logger = logging.getLogger(__name__)

SAXON_JAR = "/opt/saxon/saxon-he-12.4.jar"
_SAXON_CLASS = "net.sf.saxon.Query"

# XQuery that returns 'released', 'draft', or 'NOT_TEI_ROOT'.
# Uses text serialization to avoid XML declaration in output.
_RELEASE_STATUS_XQUERY = (
    "declare namespace tei='http://www.tei-c.org/ns/1.0'; "
    "declare namespace output='http://www.w3.org/2010/xslt-xquery-serialization'; "
    "declare option output:method 'text'; "
    "if (empty(/tei:TEI)) then 'NOT_TEI_ROOT' "
    "else if (exists(/tei:TEI/tei:teiHeader/tei:revisionDesc/"
    "tei:change[@status='released'])) then 'released' "
    "else 'draft'"
)


def resolve_release_status(tei_path: str) -> str:
    """Determine the release status of a TEI file.

    Uses Saxon XQuery to check for a revisionDesc/change element
    with status='released' in the TEI namespace.

    Returns 'released' or 'draft'.

    Raises PermanentError for malformed XML or XML without a TEI
    namespace root element.
    """
    cmd = [
        "java",
        "-cp",
        SAXON_JAR,
        _SAXON_CLASS,
        f"-s:{tei_path}",
        f"-qs:{_RELEASE_STATUS_XQUERY}",
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        stderr = result.stderr.strip()
        raise PermanentError(f"Saxon XPath evaluation failed for {tei_path}: {stderr}")

    output = result.stdout.strip()

    if output == "NOT_TEI_ROOT":
        raise PermanentError(
            f"TEI file lacks expected TEI namespace root element: {tei_path}"
        )

    if output not in ("released", "draft"):
        raise PermanentError(f"Unexpected Saxon output for {tei_path}: {output!r}")

    logger.info(
        "Resolved release status",
        extra={"context": {"tei_path": tei_path, "status": output}},
    )
    return output
