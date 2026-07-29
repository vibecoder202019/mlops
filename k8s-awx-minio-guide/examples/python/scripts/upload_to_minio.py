#!/usr/bin/env python3
"""
Upload file lên MinIO bằng boto3 (S3-compatible API).

Biến môi trường (set từ Ansible playbook):
  MINIO_ENDPOINT  — http://minio.minio.svc.cluster.local:9000
  MINIO_ACCESS_KEY
  MINIO_SECRET_KEY
  REPORT_FILE     — đường dẫn file cần upload
  MINIO_BUCKET    — bucket đích (mặc định: awx-artifacts)
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


def main() -> None:
    # Đọc config từ environment — Ansible truyền qua task environment:
    endpoint = os.environ.get("MINIO_ENDPOINT", "http://localhost:9000")
    access_key = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
    secret_key = os.environ.get("MINIO_SECRET_KEY", "minioadmin123")
    report_file = os.environ.get("REPORT_FILE", "")
    bucket = os.environ.get("MINIO_BUCKET", "awx-artifacts")

    if not report_file or not Path(report_file).exists():
        print(f"❌ File không tồn tại: {report_file}", file=sys.stderr)
        sys.exit(1)

    try:
        import boto3
        from botocore.client import Config
    except ImportError:
        print("❌ Thiếu boto3 — pip install boto3 hoặc dùng EE có boto3", file=sys.stderr)
        sys.exit(1)

    # boto3 client — endpoint_url trỏ về MinIO thay vì AWS
    client = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4"),
        region_name="us-east-1",  # MinIO bỏ qua region nhưng boto3 cần giá trị
    )

    file_path = Path(report_file)
    object_key = f"reports/{file_path.name}"

    # upload_file — upload file local lên bucket
    client.upload_file(str(file_path), bucket, object_key)

    s3_uri = f"s3://{bucket}/{object_key}"
    print(f"✅ Uploaded: {s3_uri}")
    sys.exit(0)


if __name__ == "__main__":
    main()
