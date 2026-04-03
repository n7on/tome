"""Remove items from a JSON array in a file by matching a field.

Usage:
    remove.py <file> <match_field> <match_value>

Exit codes:
    0 - item found and removed (file updated or removed if empty)
    1 - no matching item found
"""

import json
import os
import sys


def main():
    file_path = sys.argv[1]
    match_field = sys.argv[2]
    match_value = sys.argv[3]

    with open(file_path) as f:
        items = json.load(f)

    remaining = [item for item in items if item.get(match_field) != match_value]

    if len(remaining) == len(items):
        sys.exit(1)

    if remaining:
        with open(file_path, "w") as f:
            json.dump(remaining, f, indent=2)
    else:
        os.remove(file_path)


if __name__ == "__main__":
    main()
