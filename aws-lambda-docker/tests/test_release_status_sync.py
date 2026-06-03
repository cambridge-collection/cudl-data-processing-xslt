"""Guard that the tei.py XQuery and the msTeiPreFilter.xsl get-release-status
template keep using the same change-selection expression."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path

from tei import _RELEASE_STATUS_XQUERY, RELEASE_CHANGE_SELECT

XSL = "http://www.w3.org/1999/XSL/Transform"
XSLT_PATH = Path(__file__).parent.parent / "xslt" / "msTeiPreFilter.xsl"


def _collapse(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _release_status_for_each() -> ET.Element:
    tree = ET.parse(XSLT_PATH)
    template = next(
        t
        for t in tree.iter(f"{{{XSL}}}template")
        if t.get("name") == "get-release-status"
    )
    for_eaches = template.findall(f".//{{{XSL}}}for-each")
    assert len(for_eaches) == 1, "expected exactly one for-each in get-release-status"
    return for_eaches[0]


def test_xslt_select_matches_python_expression() -> None:
    select = _release_status_for_each().get("select")
    assert select is not None
    assert _collapse(select) == _collapse("root()/" + RELEASE_CHANGE_SELECT)


def test_xslt_sorts_by_when_ascending() -> None:
    sort = _release_status_for_each().find(f"{{{XSL}}}sort")
    assert sort is not None
    assert sort.get("select") == "@when"
    assert sort.get("order", "ascending") == "ascending"


def test_python_xquery_uses_shared_expression() -> None:
    xq = _collapse(_RELEASE_STATUS_XQUERY)
    assert _collapse(RELEASE_CHANGE_SELECT) in xq
    assert "order by $c/@when ascending" in xq
    assert "$statuses[last()] = 'released'" in xq
