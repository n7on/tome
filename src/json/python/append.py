"""Append a JSON object to an array in a file.

Usage:
    append.py <file> <item_json>

Creates the file with [item] if it doesn't exist.
"""

import json
import os
import sys


def main():
    file_path = sys.argv[1]
    new_item = json.loads(sys.argv[2])

    if os.path.exists(file_path):
        with open(file_path) as f:
            items = json.load(f)
    else:
        items = []

    items.append(new_item)

    with open(file_path, "w") as f:
        json.dump(items, f, indent=2)


if __name__ == "__main__":
    main()
