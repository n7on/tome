"""Accumulate paginated Graph API responses into a single JSON array.

Reads JSON from stdin (one page), appends .value to the accumulator,
and prints the next URL if there is one.

Usage:
    # Called in a loop from bash:
    echo "$page" | paginate.py <accumulator_json>
    # Outputs: line 1 = updated accumulator, line 2 = next URL (or empty)
"""

import json
import sys


def main():
    accumulator = json.loads(sys.argv[1]) if len(sys.argv) > 1 else []
    page = json.load(sys.stdin)

    values = page.get("value", [])
    accumulator.extend(values)

    print(json.dumps(accumulator, ensure_ascii=False))
    print(page.get("@odata.nextLink", ""))


if __name__ == "__main__":
    main()
