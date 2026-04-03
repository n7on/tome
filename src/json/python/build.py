"""Build a JSON object from key=value pairs.

Usage:
    build.py [--base JSON] key=value [key=value ...]

Type hints via prefix: int:count=42, float:rate=0.5, bool:active=true, json:data={...}
Nested keys via dots: retentionDuration.days=30
Empty values are omitted.
"""

import json
import sys


def set_nested(obj, path, value):
    """Set a value at a dotted path, creating intermediate dicts."""
    keys = path.split(".")
    for key in keys[:-1]:
        if key not in obj:
            obj[key] = {}
        obj = obj[key]
    obj[keys[-1]] = value


def parse_value(raw, type_hint=None):
    """Convert string value to typed value based on hint."""
    if type_hint == "int":
        return int(raw)
    if type_hint == "float":
        return float(raw)
    if type_hint == "bool":
        return raw.lower() in ("true", "1", "yes")
    if type_hint == "json":
        return json.loads(raw)
    return raw


def main():
    args = sys.argv[1:]
    base = {}
    pairs = []

    i = 0
    while i < len(args):
        if args[i] == "--base" and i + 1 < len(args):
            base = json.loads(args[i + 1])
            i += 2
        else:
            pairs.append(args[i])
            i += 1

    obj = dict(base)

    for pair in pairs:
        if "=" not in pair:
            continue
        key, value = pair.split("=", 1)
        if not value:
            continue
        type_hint = None
        if ":" in key:
            type_hint, key = key.split(":", 1)
        set_nested(obj, key, parse_value(value, type_hint))

    json.dump(obj, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
