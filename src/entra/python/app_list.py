"""List app registrations with resolved permission names.

Usage:
    app_list.py <apps_json> <graph_sp_json>

Outputs TSV with headers: name,client_id,permissions
"""

import json
import sys


def main():
    apps = json.loads(sys.argv[1])
    graph_sp = json.loads(sys.argv[2])

    perm_map = {
        p["id"]: p["value"]
        for p in graph_sp.get("scopes", []) + graph_sp.get("roles", [])
    }

    print("name,client_id,permissions")
    for app in apps:
        perms = ",".join(
            perm_map.get(ra["id"], ra["id"])
            for rra in app.get("requiredResourceAccess", [])
            for ra in rra.get("resourceAccess", [])
        )
        print(f"{app['displayName']}\t{app['appId']}\t{perms}")


if __name__ == "__main__":
    main()
