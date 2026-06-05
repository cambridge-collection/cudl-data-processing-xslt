"""TEI release-status resolution via Saxon XPath evaluation."""

from __future__ import annotations

import logging
import subprocess

from exceptions import PermanentError

logger = logging.getLogger(__name__)

SAXON_JAR = "/opt/saxon/saxon-he-12.4.jar"
_SAXON_CLASS = "net.sf.saxon.Query"

# Must stay identical to get-release-status in xslt/msTeiPreFilter.xsl;
# enforced by tests/test_release_status_sync.py.
RELEASE_CHANGE_SELECT = (
    "tei:TEI/tei:teiHeader/tei:revisionDesc/tei:change"
    "[normalize-space(@status) =('draft','redacted','released')]"
    r"[matches(@when, '^\d{4}(-\d{2})?(-\d{2})?$')]"
)

_RELEASE_STATUS_XQUERY = (
    "declare namespace tei='http://www.tei-c.org/ns/1.0'; "
    "declare namespace output='http://www.w3.org/2010/xslt-xquery-serialization'; "
    "declare option output:method 'text'; "
    "if (empty(/tei:TEI)) then 'NOT_TEI_ROOT' "
    "else ("
    "let $statuses := "
    "for $c in /" + RELEASE_CHANGE_SELECT + " "
    "order by $c/@when ascending "
    "return string($c/@status) "
    "return if ($statuses[last()] = 'released') then 'released' else 'draft'"
    ")"
)


def resolve_release_status(tei_path: str) -> str:
    """Determine the release status of a TEI file.

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
