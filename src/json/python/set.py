"""Set a key/value in a JSON file.

Usage:
    set.py <file> <key> <value>
"""

import json
import sys


def main():
    file_path = sys.argv[1]
    key = sys.argv[2]
    value = sys.argv[3]

    with open(file_path) as f:
        data = json.load(f)

    data[key] = value

    with open(file_path, "w") as f:
        json.dump(data, f, indent=2)


if __name__ == "__main__":
    main()
