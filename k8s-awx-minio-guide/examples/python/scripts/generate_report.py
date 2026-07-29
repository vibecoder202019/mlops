#!/usr/bin/env python3
"""
Tạo file report JSON — output đường dẫn file qua stdout cho task Ansible tiếp theo.

AWX chạy script này qua:
  script: scripts/generate_report.py
  register: report

Task sau đọc: {{ report.stdout | trim }}  → đường dẫn file
"""

from __future__ import annotations

import json
import platform
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    # Tạo file report trong /tmp (writable trên AWX task pod)
    report_dir = Path(tempfile.gettempdir())
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    report_path = report_dir / f"awx_report_{timestamp}.json"

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "hostname": platform.node(),
        "python": sys.version.split()[0],
        "os": platform.system(),
        "status": "completed",
        "metrics": {
            "cpu_count": 1,
            "memory_mb": 512,
        },
    }

    # Ghi file
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    # In đường dẫn ra stdout — task Ansible đọc được
    print(str(report_path))


if __name__ == "__main__":
    main()
