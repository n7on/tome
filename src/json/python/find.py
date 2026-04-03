"""Find the first matching item in a JSON array.

Usage:
    echo "$json" | find.py <array_path> <match_field> <match_value> [return_field]

Returns the matching field value, or the whole object as JSON if no return field given.
Case-insensitive matching.
"""

import json
import sys

from utils import load_stdin, resolve, resolve_root, to_string


def main():
    if len(sys.argv) < 4:
        print("Usage: find.py <array_path> <match_field> <match_value> [return_field]", file=sys.stderr)
        sys.exit(1)

    array_path = sys.argv[1]
    match_field = sys.argv[2]
    match_value = sys.argv[3]
    return_field = sys.argv[4] if len(sys.argv) > 4 else None

    data = load_stdin()
    target = resolve_root(data, array_path)

    if not isinstance(target, list):
        sys.exit(1)

    match_lower = match_value.lower()
    for item in target:
        field_val = resolve(item, match_field)
        if field_val is not None and str(field_val).lower() == match_lower:
            if return_field:
                result = resolve(item, return_field)
                if result is not None:
                    print(to_string(result))
            else:
                json.dump(item, sys.stdout, ensure_ascii=False)
            sys.exit(0)

    sys.exit(1)


if __name__ == "__main__":
    main()
