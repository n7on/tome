"""Flatten a JSON object to key/value TSV rows.

Usage:
    echo "$json" | kv.py <path>

Outputs TSV with headers: field,value
"""

import sys

from utils import load_stdin, resolve_root, to_string


def main():
    if len(sys.argv) < 2:
        print("Usage: kv.py <path>", file=sys.stderr)
        sys.exit(1)

    data = load_stdin()
    target = resolve_root(data, sys.argv[1])

    if target is None:
        sys.exit(0)

    if not isinstance(target, dict):
        print(f"Expected object at '{sys.argv[1]}', got {type(target).__name__}", file=sys.stderr)
        sys.exit(1)

    print("field,value")
    for key, value in target.items():
        print(f"{key}\t{to_string(value)}")


if __name__ == "__main__":
    main()
