"""
Render TSV data with filtering, sorting, column selection, and formatting.

Usage: echo "$data" | python3 render.py [options]

Options:
  --headers COL1,COL2,...   Column headers (required)
  --format  table|json|tsv  Output format (default: table)
  --filter  COL=value       Filter rows (= for exact/wildcard, ~ for contains)
  --sort    [-]COL          Sort by column (prefix - for descending)
  --select  COL1,COL3       Select subset of columns
  --limit   N               Limit to first N rows
  --width   N               Terminal width (default: 80)

Handles CJK wide characters, zero-width format characters, and
proper display-width truncation/padding for table output.
"""

import argparse
import fnmatch
import json
import sys
import unicodedata


# ---------------------------------------------------------------------------
# Unicode display-width helpers
# ---------------------------------------------------------------------------

def display_width(s: str) -> int:
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in s)


def strip_format(s: str) -> str:
    """Remove zero-width and Unicode format characters (e.g. U+200B)."""
    return "".join(c for c in s if unicodedata.category(c) != "Cf")


def truncate(s: str, max_width: int) -> str:
    if display_width(s) <= max_width:
        return s
    if max_width <= 1:
        return "…"[:max_width]
    used = 0
    for i, c in enumerate(s):
        cw = 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1
        if used + cw > max_width - 1:
            return s[:i] + "…"
        used += cw
    return s


def pad(s: str, width: int) -> str:
    return s + " " * max(0, width - display_width(s))


# ---------------------------------------------------------------------------
# Column resolution
# ---------------------------------------------------------------------------

def resolve_column(headers: list[str], name: str) -> int:
    """Return column index for name (case-insensitive). -1 if not found."""
    upper = name.upper()
    for i, h in enumerate(headers):
        if h.upper() == upper:
            return i
    return -1


# ---------------------------------------------------------------------------
# Data operations
# ---------------------------------------------------------------------------

def parse_rows(text: str, n_cols: int) -> list[list[str]]:
    rows = []
    for line in text.splitlines():
        if not line:
            continue
        fields = line.split("\t")
        # Pad to n_cols to avoid index errors
        while len(fields) < n_cols:
            fields.append("")
        rows.append([strip_format(f) for f in fields[:n_cols]])
    return rows


def filter_rows(headers: list[str], rows: list[list[str]], expr: str) -> list[list[str]]:
    # ~ for case-insensitive contains, = for exact/wildcard match
    if "~" in expr:
        col, _, pattern = expr.partition("~")
        idx = resolve_column(headers, col)
        if idx < 0:
            print(f"Unknown filter column: {col} (available: {','.join(headers)})", file=sys.stderr)
            return rows
        pattern_lower = pattern.lower()
        return [r for r in rows if pattern_lower in r[idx].lower()]
    else:
        col, _, pattern = expr.partition("=")
        idx = resolve_column(headers, col)
        if idx < 0:
            print(f"Unknown filter column: {col} (available: {','.join(headers)})", file=sys.stderr)
            return rows
        return [r for r in rows if fnmatch.fnmatch(r[idx], pattern)]


def sort_rows(headers: list[str], rows: list[list[str]], expr: str) -> list[list[str]]:
    descending = expr.startswith("-")
    col = expr.lstrip("-")
    idx = resolve_column(headers, col)
    if idx < 0:
        print(f"Unknown sort column: {col} (available: {','.join(headers)})", file=sys.stderr)
        return rows
    return sorted(rows, key=lambda r: r[idx], reverse=descending)


def select_columns(headers: list[str], rows: list[list[str]], expr: str) -> tuple[list[str], list[list[str]]]:
    names = [s.strip() for s in expr.split(",")]
    indices = []
    for name in names:
        idx = resolve_column(headers, name)
        if idx < 0:
            print(f"Unknown column: {name} (available: {','.join(headers)})", file=sys.stderr)
            sys.exit(1)
        indices.append(idx)
    new_headers = [headers[i] for i in indices]
    new_rows = [[r[i] for i in indices] for r in rows]
    return new_headers, new_rows


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------

def format_table(headers: list[str], rows: list[list[str]], term_width: int) -> None:
    n_cols = len(headers)
    sep = "  "
    sep_width = (n_cols - 1) * len(sep)

    # Natural column widths
    col_widths = [display_width(h) for h in headers]
    for row in rows:
        for i, val in enumerate(row):
            col_widths[i] = max(col_widths[i], display_width(val))

    # Reduce widest column until total fits terminal
    total = sum(col_widths) + sep_width
    while total > term_width:
        max_i = col_widths.index(max(col_widths))
        min_w = max(display_width(headers[max_i]), 8)
        if col_widths[max_i] <= min_w:
            break
        col_widths[max_i] -= 1
        total -= 1

    def render(values: list[str]) -> str:
        parts = []
        for val, w in zip(values, col_widths):
            parts.append(pad(truncate(val, w), w))
        return sep.join(parts).rstrip()

    print(render(headers))
    for row in rows:
        print(render(row))


def format_json(headers: list[str], rows: list[list[str]]) -> None:
    result = [{h: val for h, val in zip(headers, row)} for row in rows]
    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    print()


def format_tsv(headers: list[str], rows: list[list[str]]) -> None:
    print("\t".join(headers))
    for row in rows:
        print("\t".join(row))


def format_md(headers: list[str], rows: list[list[str]]) -> None:
    def escape(s: str) -> str:
        return s.replace("|", "\\|")

    print("| " + " | ".join(escape(h) for h in headers) + " |")
    print("| " + " | ".join("---" for _ in headers) + " |")
    for row in rows:
        print("| " + " | ".join(escape(val) for val in row) + " |")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--headers", required=True)
    parser.add_argument("--format", default="table", choices=["table", "json", "tsv", "md"])
    parser.add_argument("--filter", default=None)
    parser.add_argument("--sort", default=None)
    parser.add_argument("--select", default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--width", type=int, default=80)
    args = parser.parse_args()

    headers = args.headers.split(",")
    n_cols = len(headers)

    data = sys.stdin.read()
    rows = parse_rows(data, n_cols)

    if not rows:
        print("No results found", file=sys.stderr)
        return

    if args.filter:
        rows = filter_rows(headers, rows, args.filter)
        if not rows:
            print(f"No results match filter: {args.filter}", file=sys.stderr)
            return

    if args.sort:
        rows = sort_rows(headers, rows, args.sort)

    if args.select:
        headers, rows = select_columns(headers, rows, args.select)

    if args.limit:
        rows = rows[: args.limit]

    if args.format == "table":
        format_table(headers, rows, args.width)
    elif args.format == "json":
        format_json(headers, rows)
    elif args.format == "tsv":
        format_tsv(headers, rows)
    elif args.format == "md":
        format_md(headers, rows)


if __name__ == "__main__":
    main()
