#!/usr/bin/env python3
"""Partition build outputs into released vs unreleased by scanning core-xml.

For every core-xml file with <boolean key="itemReleased">false</boolean>, the
matching family of artifacts (core-xml, dp-json, solr-json, viewer-json, html,
page-xml, tei-full) is moved from the released layout under <dist_pending>/<dir>/
into <dist_pending>/unreleased/<dir>/, preserving each output type's internal
path structure. Downstream copy/sync targets carry the unreleased/ subtree
through to dist/unreleased/ or s3://<bucket>/unreleased/ without further
changes.

Driven from build.xml's _partition-unreleased target. Reads core_xml_dir
because that dir's location varies (default dist-pending/core-xml, env override,
or tmp/core-xml when SKIP_CORE_XML_COPY=true).
"""

from __future__ import annotations

import argparse
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

JSON_NS = "{http://www.w3.org/2005/xpath-functions}"


def find_unreleased_stems(core_xml_dir: Path) -> list[str]:
    """Return the filename stem of every core-xml file with itemReleased=false."""
    if not core_xml_dir.is_dir():
        return []

    stems: list[str] = []
    for path in sorted(core_xml_dir.rglob("*.xml")):
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as exc:
            print(f"  warn: could not parse {path}: {exc}", file=sys.stderr)
            continue

        for elem in root.iter(f"{JSON_NS}boolean"):
            if elem.get("key") != "itemReleased":
                continue
            if (elem.text or "").strip().lower() == "false":
                stems.append(path.stem)
            break

    return stems


def move_flat(src_dir: Path, dest_dir: Path, stems: list[str]) -> int:
    """Move <stem>.json files from src_dir to dest_dir. Returns count moved."""
    if not src_dir.is_dir():
        return 0
    moved = 0
    for stem in stems:
        src = src_dir / f"{stem}.json"
        if src.is_file():
            dest = dest_dir / f"{stem}.json"
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src), str(dest))
            moved += 1
    return moved


def move_nested(src_dir: Path, dest_dir: Path, stems: list[str]) -> int:
    """Move every subdirectory whose name is one of the stems.

    Preserves the relative path from src_dir so e.g.
    src_dir/items/data/tei/X/  -> dest_dir/items/data/tei/X/
    """
    if not src_dir.is_dir():
        return 0
    stem_set = set(stems)
    to_move = [p for p in src_dir.rglob("*") if p.is_dir() and p.name in stem_set]
    moved = 0
    for candidate in to_move:
        if not candidate.exists():
            continue
        rel = candidate.relative_to(src_dir)
        dest = dest_dir / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(candidate), str(dest))
        moved += 1
    return moved


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-xml-dir", required=True, type=Path)
    parser.add_argument("--dist-pending", required=True, type=Path)
    parser.add_argument("--page-xml-dir", type=Path,
                        help="Defaults to <dist-pending>/page-xml")
    parser.add_argument("--skip-core-xml", action="store_true")
    parser.add_argument("--skip-page-xml", action="store_true")
    parser.add_argument("--skip-tei-full", action="store_true")
    args = parser.parse_args()

    stems = find_unreleased_stems(args.core_xml_dir)
    if not stems:
        print("partition: no unreleased items found; skipping")
        return 0

    print(f"partition: {len(stems)} unreleased item(s):")
    for s in stems:
        print(f"  - {s}")

    unreleased = args.dist_pending / "unreleased"

    moved_flat_dp = move_flat(args.dist_pending / "dp-json",
                              unreleased / "dp-json", stems)
    moved_flat_solr = move_flat(args.dist_pending / "solr-json",
                                unreleased / "solr-json", stems)
    moved_flat_viewer = move_flat(args.dist_pending / "json",
                                  unreleased / "json", stems)

    moved_core = 0
    if not args.skip_core_xml:
        moved_core = move_nested(args.core_xml_dir,
                                 unreleased / "core-xml", stems)

    moved_html = move_nested(args.dist_pending / "html",
                             unreleased / "html", stems)

    moved_page = 0
    if not args.skip_page_xml:
        page_xml_dir = args.page_xml_dir or (args.dist_pending / "page-xml")
        moved_page = move_nested(page_xml_dir,
                                 unreleased / "page-xml", stems)

    moved_items = 0
    if not args.skip_tei_full:
        moved_items = move_nested(args.dist_pending / "items",
                                  unreleased / "items", stems)

    print(
        f"partition: moved dp-json={moved_flat_dp} solr-json={moved_flat_solr} "
        f"json={moved_flat_viewer} core-xml={moved_core} html={moved_html} "
        f"page-xml={moved_page} items={moved_items}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
