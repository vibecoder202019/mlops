#!/usr/bin/env python3
"""
Liệt kê resource AWX qua API — hữu ích khi debug hoặc khám phá API.

Cách chạy:
  export AWX_URL="http://localhost:8052"
  export AWX_TOKEN="your-token"

  python list_resources.py templates
  python list_resources.py inventories
  python list_resources.py projects
  python list_resources.py jobs
"""

from __future__ import annotations

import argparse
import sys

from awx_client import _client_from_env

# Map tên CLI → endpoint AWX API
ENDPOINTS = {
    "templates": "/job_templates/",
    "inventories": "/inventories/",
    "projects": "/projects/",
    "jobs": "/jobs/",
    "credentials": "/credentials/",
    "organizations": "/organizations/",
}


def main() -> None:
    parser = argparse.ArgumentParser(description="Liệt kê AWX resources")
    parser.add_argument(
        "resource",
        choices=list(ENDPOINTS.keys()),
        help="Loại resource cần liệt kê",
    )
    parser.add_argument("--limit", type=int, default=20, help="Số bản ghi tối đa")
    args = parser.parse_args()

    client = _client_from_env()
    endpoint = ENDPOINTS[args.resource]

    try:
        result = client.get(endpoint, params={"page_size": args.limit})
    except Exception as exc:
        print(f"❌ Lỗi API: {exc}", file=sys.stderr)
        sys.exit(1)

    items = result.get("results", [])
    total = result.get("count", len(items))

    print(f"\n{args.resource.upper()} ({len(items)}/{total}):\n")
    print(f"{'ID':>6}  {'Name':<40}  Extra")
    print("-" * 70)

    for item in items:
        item_id = item.get("id", "?")
        name = item.get("name", item.get("job_template_name", "?"))[:40]

        extra = ""
        if args.resource == "jobs":
            extra = f"status={item.get('status')}"
        elif args.resource == "templates":
            extra = f"playbook={item.get('playbook', '')}"
        elif args.resource == "projects":
            extra = f"scm={item.get('scm_type')}"

        print(f"{item_id:>6}  {name:<40}  {extra}")


if __name__ == "__main__":
    main()
