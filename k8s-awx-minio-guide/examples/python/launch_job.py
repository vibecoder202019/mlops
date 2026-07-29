#!/usr/bin/env python3
"""
Launch AWX Job Template từ Python — ví dụ workflow hoàn chỉnh.

Cách chạy:
  export AWX_URL="http://localhost:8052"
  export AWX_TOKEN="your-token"

  # Launch theo tên template và đợi kết quả
  python launch_job.py --template-name "Python Hello World" --wait

  # Launch kèm biến truyền vào playbook
  python launch_job.py --template-id 7 --extra-vars '{"user_name": "Python"}' --wait
"""

from __future__ import annotations

import argparse
import json
import sys

# Import client từ cùng thư mục
from awx_client import AWXClient, _client_from_env


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Launch AWX job và tuỳ chọn đợi kết quả",
    )
    parser.add_argument("--template-id", type=int, help="ID Job Template")
    parser.add_argument("--template-name", help="Tên Job Template")
    parser.add_argument(
        "--extra-vars",
        help='Biến truyền vào playbook, JSON: \'{"key": "value"}\'',
    )
    parser.add_argument(
        "--wait",
        action="store_true",
        help="Poll đến khi job successful/failed",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=600,
        help="Timeout khi --wait (giây, mặc định 600)",
    )
    args = parser.parse_args()

    client: AWXClient = _client_from_env()

    # Xác định template id
    template_id = args.template_id
    if args.template_name:
        tmpl = client.get_job_template_by_name(args.template_name)
        if not tmpl:
            print(f"❌ Không tìm thấy template: {args.template_name}", file=sys.stderr)
            sys.exit(1)
        template_id = tmpl["id"]
        print(f"📋 Template: {args.template_name} (id={template_id})")

    if not template_id:
        print("❌ Cần --template-id hoặc --template-name", file=sys.stderr)
        sys.exit(1)

    # Parse extra vars
    extra_vars = None
    if args.extra_vars:
        extra_vars = json.loads(args.extra_vars)
        print(f"📦 Extra vars: {extra_vars}")

    # Launch job
    print("🚀 Launching job...")
    launch_result = client.launch_job(template_id, extra_vars=extra_vars)
    job_id = launch_result.get("job")

    if not job_id:
        print("❌ API không trả về job id:", launch_result, file=sys.stderr)
        sys.exit(1)

    print(f"✅ Job created: id={job_id}")
    print(f"   Xem trên AWX UI: {client.base_url}/#/jobs/playbook/{job_id}")

    if not args.wait:
        print("\n💡 Thêm --wait để đợi job hoàn thành")
        return

    # Poll status
    print("\n⏳ Đang đợi job...")
    try:
        job = client.wait_for_job(job_id, timeout=args.timeout)
    except TimeoutError as exc:
        print(f"❌ {exc}", file=sys.stderr)
        sys.exit(1)

    status = job.get("status")
    print(f"\n{'✅' if status == 'successful' else '❌'} Job {job_id}: {status}")

    if status == "successful":
        print("\n--- Job Output (stdout) ---")
        print(client.get_job_stdout(job_id))
    elif job.get("job_explanation"):
        print(f"Giải thích: {job['job_explanation']}")

    sys.exit(0 if status == "successful" else 1)


if __name__ == "__main__":
    main()
