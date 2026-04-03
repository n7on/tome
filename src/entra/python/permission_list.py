"""List Microsoft Graph permission scopes and app roles.

Usage:
    echo "$graph_sp_json" | permission_list.py

Outputs TSV with headers: permission,type,description
Sorted alphabetically by permission name.
"""

import json
import sys


def main():
    sp = json.load(sys.stdin)

    permissions = []

    for scope in sp.get("oauth2PermissionScopes", []):
        permissions.append({
            "value": scope.get("value", "-"),
            "type": "delegated",
            "description": scope.get("adminConsentDescription", "-") or "-",
        })

    for role in sp.get("appRoles", []):
        permissions.append({
            "value": role.get("value", "-"),
            "type": "application",
            "description": role.get("description", "-") or "-",
        })

    permissions.sort(key=lambda p: p["value"].lower())

    print("permission,type,description")
    for p in permissions:
        print(f"{p['value']}\t{p['type']}\t{p['description']}")


if __name__ == "__main__":
    main()
