"""Get a single value from JSON by path.

Usage:
    echo "$json" | get.py <path>

Returns empty for null/missing values (exit 0, no output).
"""

import sys

from utils import load_stdin, resolve_root, to_string


def main():
    if len(sys.argv) < 2:
        print("Usage: get.py <path>", file=sys.stderr)
        sys.exit(1)

    data = load_stdin()
    target = resolve_root(data, sys.argv[1])

    if target is None:
        sys.exit(0)

    if isinstance(target, bool):
        print(str(target).lower())
    elif isinstance(target, (list, dict)):
        import json
        json.dump(target, sys.stdout, ensure_ascii=False)
    else:
        print(target)


if __name__ == "__main__":
    main()
