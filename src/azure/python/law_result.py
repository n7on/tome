"""Convert Azure Log Analytics query results to TSV with headers.

Handles both formats:
  - New az CLI format: array of objects
  - Old format: tables structure with columns and rows

Usage:
    echo "$result" | law_result.py
"""

import json
import sys


def main():
    data = json.load(sys.stdin)

    if isinstance(data, list):
        # New format: array of objects
        if not data:
            sys.exit(0)
        keys = list(data[0].keys())
        print(",".join(k.lower() for k in keys))
        for row in data:
            print("\t".join(str(row.get(k) or "") for k in keys))
    elif isinstance(data, dict) and "tables" in data:
        # Old format: tables structure
        table = data["tables"][0]
        columns = [c["name"] for c in table["columns"]]
        print(",".join(c.lower() for c in columns))
        for row in table["rows"]:
            print("\t".join(str(v) if v is not None else "" for v in row))
    else:
        print("Unexpected result format", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
