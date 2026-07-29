#!/usr/bin/env python3
"""
Script Python mẫu — được Ansible 'script' module gọi từ playbook AWX.

Ansible copy script này lên target host và chạy: python3 process_data.py
Output stdout sẽ được Ansible capture vào registered variable.

Chạy trực tiếp để test:
  python3 process_data.py
  python3 process_data.py --name "AWX Lab"
"""

from __future__ import annotations

import argparse
import json
import platform
import sys
from datetime import datetime, timezone


def main() -> None:
    parser = argparse.ArgumentParser(description="Xử lý data demo cho AWX")
    parser.add_argument("--name", default="Học viên", help="Tên người dùng")
    args = parser.parse_args()

    # Tạo dict kết quả — dễ parse nếu cần
    result = {
        "message": f"Xin chào {args.name}!",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "python_version": sys.version.split()[0],
        "platform": platform.platform(),
        "hostname": platform.node(),
    }

    # In JSON ra stdout — Ansible capture qua register.stdout
    print(json.dumps(result, indent=2, ensure_ascii=False))

    # Exit code 0 = thành công (Ansible coi task là ok)
    sys.exit(0)


if __name__ == "__main__":
    main()
