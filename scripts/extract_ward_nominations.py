#!/usr/bin/env python3
"""Extract Manchester ward nomination tables into markdown details blocks."""

from __future__ import annotations

import argparse
import html
import re
import sys
import time
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin
from urllib.request import Request, urlopen

INDEX_URL = (
    "https://www.manchester.gov.uk/the-council-and-democracy/"
    "elections-and-voting/elections/"
    "statement-of-persons-nominated-may-2026-local-elections2"
)

WARD_NAMES = [
    "Ancoats and Beswick",
    "Ardwick",
    "Baguley",
    "Brooklands",
    "Burnage",
    "Charlestown",
    "Cheetham",
    "Chorlton",
    "Chorlton Park",
    "Clayton and Openshaw",
    "Crumpsall",
    "Deansgate",
    "Didsbury East",
    "Didsbury West",
    "Fallowfield",
    "Gorton and Abbey Hey",
    "Harpurhey",
    "Higher Blackley",
    "Hulme",
    "Levenshulme",
    "Longsight",
    "Miles Platting and Newton Heath",
    "Moss Side",
    "Moston",
    "Northenden",
    "Old Moat",
    "Piccadilly",
    "Rusholme",
    "Sharston",
    "Whalley Range",
    "Withington",
    "Woodhouse Park",
]


class AnchorParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self._in_anchor = False
        self._href = ""
        self._buffer: list[str] = []
        self.anchors: list[tuple[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "a":
            return
        self._in_anchor = True
        self._buffer = []
        attr_map = dict(attrs)
        self._href = attr_map.get("href") or ""

    def handle_data(self, data: str) -> None:
        if self._in_anchor:
            self._buffer.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag != "a" or not self._in_anchor:
            return
        text = _normalize_text("".join(self._buffer))
        self.anchors.append((text, self._href))
        self._in_anchor = False
        self._href = ""
        self._buffer = []


class TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.tables: list[list[list[str]]] = []
        self._table_depth = 0
        self._rows: list[list[str]] = []
        self._current_row: list[str] = []
        self._cell_open = False
        self._cell_buffer: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "table":
            self._table_depth += 1
            if self._table_depth == 1:
                self._rows = []
        elif self._table_depth == 1 and tag == "tr":
            self._current_row = []
        elif self._table_depth == 1 and tag in {"td", "th"}:
            self._cell_open = True
            self._cell_buffer = []
        elif self._table_depth == 1 and tag == "br" and self._cell_open:
            self._cell_buffer.append("\n")

    def handle_data(self, data: str) -> None:
        if self._table_depth == 1 and self._cell_open:
            self._cell_buffer.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag in {"td", "th"} and self._table_depth == 1 and self._cell_open:
            text = _normalize_text("".join(self._cell_buffer))
            self._current_row.append(text)
            self._cell_open = False
            self._cell_buffer = []
            return

        if tag == "tr" and self._table_depth == 1:
            if any(cell.strip() for cell in self._current_row):
                self._rows.append(self._current_row)
            self._current_row = []
            return

        if tag == "table":
            if self._table_depth == 1 and self._rows:
                self.tables.append(self._rows)
            self._table_depth = max(0, self._table_depth - 1)


def _normalize_text(value: str) -> str:
    value = html.unescape(value)
    value = re.sub(r"\s+", " ", value).strip()
    return value


def _markdown_escape(value: str) -> str:
    return value.replace("|", r"\|")


def fetch(url: str, timeout_seconds: float = 12.0, retries: int = 2) -> tuple[str, str]:
    request = Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (compatible; WardNominationExtractor/1.0; +https://example.local)"
            )
        },
    )
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            with urlopen(request, timeout=timeout_seconds) as response:
                body = response.read()
                content_type = (
                    response.headers.get_content_type() or "application/octet-stream"
                )
            text = body.decode("utf-8", errors="replace")
            return text, content_type
        except Exception as error:  # pylint: disable=broad-except
            last_error = error
            if attempt < retries:
                time.sleep(0.5 * (attempt + 1))
    assert last_error is not None
    raise last_error


def discover_ward_links(index_html: str, base_url: str) -> list[tuple[str, str]]:
    parser = AnchorParser()
    parser.feed(index_html)

    links: list[tuple[str, str]] = []
    ward_lookup = {name.casefold(): name for name in WARD_NAMES}
    seen: set[str] = set()

    for label, href in parser.anchors:
        canonical = ward_lookup.get(label.casefold())
        if not canonical or not href:
            continue
        if canonical in seen:
            continue
        seen.add(canonical)
        links.append((canonical, urljoin(base_url, href)))

    links.sort(key=lambda item: WARD_NAMES.index(item[0]))
    return links


def choose_table(tables: list[list[list[str]]]) -> list[list[str]] | None:
    if not tables:
        return None
    ranked = sorted(
        tables,
        key=lambda table: (
            len(table),
            max((len(row) for row in table), default=0),
        ),
        reverse=True,
    )
    best = ranked[0]
    if len(best) < 2:
        return None
    return best


def to_markdown_bullets(rows: list[list[str]]) -> str:
    width = max((len(row) for row in rows), default=0)
    if width == 0:
        return "_No rows found._"

    normalized_rows = [row + [""] * (width - len(row)) for row in rows]
    header = normalized_rows[0]
    body = normalized_rows[1:]

    lines: list[str] = []
    for row in body:
        pairs = [
            (label.strip() or f"Column {idx + 1}", value.strip())
            for idx, (label, value) in enumerate(zip(header, row))
        ]
        populated = [(label, value) for label, value in pairs if value]
        if not populated:
            continue

        first_label, first_value = populated[0]
        lines.append(f"- **{_markdown_escape(first_value)}**")
        lines.append(f"  - {_markdown_escape(first_label)}: {_markdown_escape(first_value)}")
        for label, value in populated[1:]:
            lines.append(f"  - {_markdown_escape(label)}: {_markdown_escape(value)}")
    if not lines:
        return "_No candidate rows found._"
    return "\n".join(lines)


def render_details_block(ward_name: str, source_url: str, bullet_markdown: str) -> str:
    return (
        f"<details>\n"
        f"<summary>{ward_name}</summary>\n\n"
        f"Source: [{source_url}]({source_url})\n\n"
        f"{bullet_markdown}\n\n"
        f"</details>"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract Manchester ward nomination tables as markdown details blocks."
    )
    parser.add_argument(
        "--output",
        default="ward-nominations.md",
        help="Output markdown path (default: ward-nominations.md)",
    )
    parser.add_argument(
        "--index-url",
        default=INDEX_URL,
        help="Index page URL to read ward links from.",
    )
    args = parser.parse_args()

    try:
        index_html, _ = fetch(args.index_url)
    except Exception as error:  # pylint: disable=broad-except
        print(f"Failed to fetch index page: {error}", file=sys.stderr)
        return 1

    ward_links = discover_ward_links(index_html, args.index_url)
    if not ward_links:
        print("No ward links found on the index page.", file=sys.stderr)
        return 1

    details_blocks: list[str] = []
    unparsed: list[tuple[str, str, str]] = []

    for ward_name, ward_url in ward_links:
        print(f"Processing: {ward_name}")
        try:
            ward_html, content_type = fetch(ward_url)
        except Exception as error:  # pylint: disable=broad-except
            unparsed.append((ward_name, ward_url, f"fetch_error: {error}"))
            continue

        if "html" not in content_type:
            unparsed.append((ward_name, ward_url, f"content_type: {content_type}"))
            continue

        table_parser = TableParser()
        table_parser.feed(ward_html)
        table = choose_table(table_parser.tables)

        if not table:
            unparsed.append((ward_name, ward_url, "no_table_found"))
            continue

        bullet_markdown = to_markdown_bullets(table)
        details_blocks.append(render_details_block(ward_name, ward_url, bullet_markdown))

    output_parts = ["# Manchester Ward Nominations (May 2026)", ""]
    output_parts.append(f"- Wards discovered: {len(ward_links)}")
    output_parts.append(f"- Wards parsed: {len(details_blocks)}")
    output_parts.append(f"- Wards unparsed: {len(unparsed)}")
    output_parts.append("")
    output_parts.extend(details_blocks)

    if unparsed:
        output_parts.append("")
        output_parts.append("## Unparsed links")
        output_parts.append("")
        for ward_name, ward_url, reason in unparsed:
            output_parts.append(f"- {ward_name}: [{ward_url}]({ward_url}) ({reason})")

    output_path = Path(args.output)
    output_path.write_text("\n".join(output_parts) + "\n", encoding="utf-8")

    print(f"Wrote {output_path}")
    print(f"Discovered wards: {len(ward_links)}")
    print(f"Parsed wards: {len(details_blocks)}")
    print(f"Unparsed wards: {len(unparsed)}")
    if unparsed:
        print("Unparsed ward list:")
        for ward_name, _, reason in unparsed:
            print(f" - {ward_name} ({reason})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
