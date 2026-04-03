"""Extract fields from a JSON array as TSV with headers.

Usage:
    echo "$json" | tsv.py <path> <fields>

    Fields are comma-separated: 'name=displayName,id,active=isActive'
    No rename: field name is lowercased for the header.
"""

import sys

from utils import load_stdin, resolve, resolve_root, to_string


def parse_fields(fields_str):
    """Parse 'name=displayName,id' into (header, field_path) tuples."""
    mappings = []
    for field in fields_str.split(","):
        field = field.strip()
        if "=" in field:
            header, path = field.split("=", 1)
            mappings.append((header, path))
        else:
            mappings.append((field.lower(), field))
    return mappings


def main():
    if len(sys.argv) < 3:
        print("Usage: tsv.py <path> <fields>", file=sys.stderr)
        sys.exit(1)

    root_path = sys.argv[1]
    fields_str = sys.argv[2]

    data = load_stdin()
    target = resolve_root(data, root_path)

    if target is None:
        sys.exit(0)

    mappings = parse_fields(fields_str)

    # Ensure target is iterable
    if isinstance(target, dict):
        target = [target]
    elif not isinstance(target, list):
        print(f"Expected array or object at '{root_path}', got {type(target).__name__}", file=sys.stderr)
        sys.exit(1)

    # Print headers
    print(",".join(h for h, _ in mappings))

    # Print rows
    for item in target:
        fields = []
        for _, field_path in mappings:
            value = resolve(item, field_path)
            fields.append(to_string(value))
        print("\t".join(fields))


if __name__ == "__main__":
    main()
