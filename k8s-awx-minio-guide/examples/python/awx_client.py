#!/usr/bin/env python3
"""
AWX REST API Client — wrapper đơn giản cho người mới học.

Cách dùng:
  export AWX_URL="http://localhost:8052"
  export AWX_TOKEN="your-api-token"

  python awx_client.py list-templates
  python awx_client.py launch --template-id 7
  python awx_client.py job-status --job-id 42
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from typing import Any

import requests


class AWXClient:
    """Client gọi AWX REST API v2."""

    def __init__(self, base_url: str, token: str) -> None:
        # base_url — URL gốc AWX, ví dụ http://localhost:8052
        self.base_url = base_url.rstrip("/")
        # session — tái sử dụng TCP connection, nhanh hơn gọi từng request
        self.session = requests.Session()
        # Token auth — AWX dùng Bearer token thay vì username/password
        self.session.headers.update(
            {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            }
        )

    def _url(self, path: str) -> str:
        """Ghép base URL + path API."""
        path = path if path.startswith("/") else f"/{path}"
        return f"{self.base_url}/api/v2{path}"

    def get(self, path: str, params: dict | None = None) -> dict[str, Any]:
        """GET request — lấy dữ liệu (list templates, job status...)."""
        resp = self.session.get(self._url(path), params=params, timeout=30)
        resp.raise_for_status()
        return resp.json()

    def post(self, path: str, data: dict | None = None) -> dict[str, Any]:
        """POST request — tạo resource hoặc launch job."""
        resp = self.session.post(self._url(path), json=data or {}, timeout=30)
        resp.raise_for_status()
        return resp.json()

    def list_job_templates(self) -> list[dict[str, Any]]:
        """Liệt kê tất cả Job Template."""
        result = self.get("/job_templates/")
        return result.get("results", [])

    def get_job_template_by_name(self, name: str) -> dict[str, Any] | None:
        """Tìm Job Template theo tên."""
        templates = self.list_job_templates()
        for tmpl in templates:
            if tmpl.get("name") == name:
                return tmpl
        return None

    def launch_job(
        self,
        template_id: int,
        extra_vars: dict | None = None,
    ) -> dict[str, Any]:
        """
        Launch Job Template.

        POST /api/v2/job_templates/{id}/launch/
        Trả về dict chứa key "job" = job id mới tạo.
        """
        payload: dict[str, Any] = {}
        if extra_vars:
            payload["extra_vars"] = extra_vars
        return self.post(f"/job_templates/{template_id}/launch/", payload)

    def get_job(self, job_id: int) -> dict[str, Any]:
        """Lấy thông tin job (status, started, finished...)."""
        return self.get(f"/jobs/{job_id}/")

    def wait_for_job(
        self,
        job_id: int,
        poll_interval: int = 5,
        timeout: int = 600,
    ) -> dict[str, Any]:
        """
        Poll job đến khi successful/failed/canceled.

        poll_interval — giây giữa mỗi lần kiểm tra
        timeout — tối đa chờ bao nhiêu giây
        """
        terminal = {"successful", "failed", "error", "canceled"}
        elapsed = 0
        while elapsed < timeout:
            job = self.get_job(job_id)
            status = job.get("status", "unknown")
            print(f"  Job {job_id}: {status}")
            if status in terminal:
                return job
            time.sleep(poll_interval)
            elapsed += poll_interval
        raise TimeoutError(f"Job {job_id} chưa hoàn thành sau {timeout}s")

    def get_job_stdout(self, job_id: int) -> str:
        """Lấy output stdout của job (plain text)."""
        resp = self.session.get(
            self._url(f"/jobs/{job_id}/stdout/"),
            params={"format": "txt"},
            timeout=30,
        )
        resp.raise_for_status()
        return resp.text


def _client_from_env() -> AWXClient:
    """Đọc AWX_URL và AWX_TOKEN từ biến môi trường."""
    url = os.environ.get("AWX_URL", "http://localhost:8052")
    token = os.environ.get("AWX_TOKEN")
    if not token:
        print(
            "❌ Thiếu AWX_TOKEN.\n"
            "   Tạo token: AWX UI → User → Tokens → Create\n"
            "   export AWX_TOKEN='your-token'",
            file=sys.stderr,
        )
        sys.exit(1)
    return AWXClient(url, token)


def main() -> None:
    parser = argparse.ArgumentParser(description="AWX API Client — lab demo")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list-templates", help="Liệt kê Job Template")

    p_launch = sub.add_parser("launch", help="Launch Job Template")
    p_launch.add_argument("--template-id", type=int, help="ID Job Template")
    p_launch.add_argument("--template-name", help="Tên Job Template")
    p_launch.add_argument("--extra-vars", help='JSON extra vars, ví dụ \'{"key":"val"}\'')
    p_launch.add_argument("--wait", action="store_true", help="Đợi job hoàn thành")

    p_status = sub.add_parser("job-status", help="Xem trạng thái job")
    p_status.add_argument("--job-id", type=int, required=True)

    args = parser.parse_args()
    client = _client_from_env()

    if args.command == "list-templates":
        templates = client.list_job_templates()
        print(f"Tìm thấy {len(templates)} Job Template:\n")
        for t in templates:
            print(f"  ID={t['id']:4d}  Name={t['name']}")

    elif args.command == "launch":
        tmpl_id = args.template_id
        if args.template_name:
            tmpl = client.get_job_template_by_name(args.template_name)
            if not tmpl:
                print(f"❌ Không tìm thấy template: {args.template_name}", file=sys.stderr)
                sys.exit(1)
            tmpl_id = tmpl["id"]
        if not tmpl_id:
            print("❌ Cần --template-id hoặc --template-name", file=sys.stderr)
            sys.exit(1)

        extra = json.loads(args.extra_vars) if args.extra_vars else None
        result = client.launch_job(tmpl_id, extra_vars=extra)
        job_id = result.get("job")
        print(f"✅ Launched job ID={job_id}")

        if args.wait and job_id:
            print("Đang đợi job hoàn thành...")
            job = client.wait_for_job(job_id)
            print(f"\nKết quả: {job.get('status')}")
            if job.get("status") == "successful":
                print("\n--- STDOUT ---")
                print(client.get_job_stdout(job_id))

    elif args.command == "job-status":
        job = client.get_job(args.job_id)
        print(json.dumps(job, indent=2, default=str))


if __name__ == "__main__":
    main()
