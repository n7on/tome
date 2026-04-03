"""Join users with SKU and MFA data to produce a user list.

Usage:
    user_list.py <users_json> <skus_json> <mfa_json>

Outputs TSV with headers: name,upn,account,mfa,licenses
"""

import json
import sys


def main():
    users = json.loads(sys.argv[1])
    skus = json.loads(sys.argv[2])
    mfa_data = json.loads(sys.argv[3])

    sku_map = {s["skuId"]: s["skuPartNumber"] for s in skus if "skuId" in s}
    mfa_map = {m["userPrincipalName"]: m.get("isMfaRegistered", False) for m in mfa_data}

    print("name,upn,account,mfa,licenses")
    for user in users:
        upn = user.get("userPrincipalName", "-")
        account = "enabled" if user.get("accountEnabled") else "disabled"
        mfa = "yes" if mfa_map.get(upn) else "no"

        assigned = user.get("assignedLicenses", [])
        if assigned:
            licenses = ",".join(sku_map.get(lic["skuId"], "unknown") for lic in assigned)
        else:
            licenses = "none"

        print(f"{user.get('displayName', '-')}\t{upn}\t{account}\t{mfa}\t{licenses}")


if __name__ == "__main__":
    main()
