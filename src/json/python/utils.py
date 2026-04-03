"""Shared JSON utilities."""

import json


def resolve(obj, path):
    """Traverse a dotted path like 'retentionDuration.days' or 'subscriptions.0.user.name'."""
    for key in path.split("."):
        if obj is None:
            return None
        if isinstance(obj, list):
            try:
                obj = obj[int(key)]
            except (ValueError, IndexError):
                return None
        elif isinstance(obj, dict):
            obj = obj.get(key)
        else:
            return None
    return obj


def to_string(value):
    """Convert a value to a display string."""
    if value is None:
        return "-"
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (list, dict)):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def load_stdin():
    """Load JSON from stdin."""
    import sys
    return json.load(sys.stdin)


def resolve_root(data, path):
    """Resolve a root path, treating '.' as identity."""
    if path == ".":
        return data
    return resolve(data, path)
