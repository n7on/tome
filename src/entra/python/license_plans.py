"""Flatten SKU + service plan data to TSV.

Each SKU contains multiple service plans. This outputs one row per plan,
with the parent SKU name on each row.

Usage:
    echo "$skus_json" | license_plans.py
"""

import json
import sys


def main():
    skus = json.load(sys.stdin)

    print("sku,plan,status,applies_to")
    for sku in skus:
        sku_name = sku.get("skuPartNumber", "-")
        for plan in sku.get("servicePlans", []):
            print("\t".join([
                sku_name,
                plan.get("servicePlanName", "-"),
                plan.get("provisioningStatus", "-"),
                plan.get("appliesTo", "-"),
            ]))


if __name__ == "__main__":
    main()
