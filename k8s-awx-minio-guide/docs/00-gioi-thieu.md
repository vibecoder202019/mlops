# 00 — Giới thiệu AWX & MinIO

## AWX là gì?

**AWX** là phiên bản mã nguồn mở của Red Hat Ansible Automation Platform (trước đây gọi là Ansible Tower). Nó cung cấp:

- **Giao diện web** để quản lý playbook Ansible
- **Job Template** — chạy playbook theo lịch hoặc thủ công
- **Inventory** — danh sách máy chủ cần quản lý
- **Credential** — lưu SSH key, password, token an toàn
- **RBAC** — phân quyền người dùng theo team/organization

### Luồng hoạt động cơ bản

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  AWX Web UI │ ──► │ Job Template │ ──► │ Ansible Runner  │
│  (người dùng)│     │  + Playbook  │     │ (thực thi job)  │
└─────────────┘     └──────────────┘     └────────┬────────┘
                                                   │
                                                   ▼
                                          ┌─────────────────┐
                                          │ Target hosts    │
                                          │ (inventory)     │
                                          └─────────────────┘
```

### AWX trên Kubernetes

AWX được cài bằng **AWX Operator** — một Kubernetes Operator quản lý vòng đời AWX (cài, nâng cấp, backup). Operator tự tạo:

- PostgreSQL (database nội bộ)
- Redis (cache/message queue)
- AWX web pod + task pod
- Service, Ingress

---

## MinIO là gì?

**MinIO** là hệ thống **object storage** hiệu năng cao, tương thích **Amazon S3 API**. Dùng để:

- Lưu file, backup, log
- Lưu artifact CI/CD
- Lưu playbook/project cho AWX (thay vì Git)

### Khái niệm quan trọng

| Thuật ngữ | Giải thích |
|-----------|------------|
| **Bucket** | "Thư mục" cấp cao nhất (giống S3 bucket) |
| **Object** | File được lưu trong bucket |
| **Access Key / Secret Key** | Credential truy cập API (giống AWS IAM key) |
| **Console** | Giao diện web quản lý bucket |

### MinIO trong lab này

Chúng ta dùng MinIO để:

1. Lưu trữ playbook Ansible (project SCM type = S3)
2. Lưu artifact sau khi job AWX chạy xong
3. Học cách dùng S3-compatible storage trên K8s

---

## Python trong lab này

**Python** xuất hiện ở 3 vai trò:

| Vai trò | Ví dụ |
|---------|-------|
| Trong playbook AWX | `script` module, custom module `hello_python` |
| Gọi AWX API | `awx_client.py`, `launch_job.py` — trigger job từ CI/CD |
| Upload MinIO | `upload_to_minio.py` dùng boto3 (S3 API) |

Chi tiết: [07-tich-hop-awx-python.md](07-tich-hop-awx-python.md)

---

## Tại sao triển khai trên Kubernetes?

| Lợi ích | Giải thích |
|---------|------------|
| Nhất quán | Cùng một cách deploy dev/staging/prod |
| Tự heal | K8s tự restart pod khi crash |
| Scale | AWX Operator hỗ trợ scale task node |
| Học tập | K8s là kỹ năng cốt lõi DevOps/MLOps |

---

## Kiến trúc tổng thể lab

```
                    ┌──────────────────────────────────────┐
                    │         Kubernetes Cluster           │
                    │                                      │
  Browser ─────────►│  ┌─────────┐      ┌──────────────┐  │
  awx.local         │  │ Ingress │      │   Ingress    │  │◄── minio.local
                    │  │  (AWX)  │      │   (MinIO)    │  │
                    │  └────┬────┘      └──────┬───────┘  │
                    │       │                  │          │
                    │  ┌────▼────┐      ┌──────▼───────┐  │
                    │  │   AWX   │─────►│    MinIO     │  │
                    │  │ (Operator│ S3   │  (object     │  │
                    │  │ instance)│ API  │   storage)   │  │
                    │  └─────────┘      └──────────────┘  │
                    │       │                  │          │
                    │  ┌────▼────┐      ┌──────▼───────┐  │
                    │  │PostgreSQL│     │     PVC      │  │
                    │  │ (AWX DB) │     │  (MinIO data)│  │
                    │  └─────────┘      └──────────────┘  │
                    └──────────────────────────────────────┘
```

---

## Thuật ngữ cần biết trước

| Thuật ngữ | Ý nghĩa ngắn gọn |
|-----------|------------------|
| **Pod** | Đơn vị nhỏ nhất chạy container trên K8s |
| **Deployment** | Quản lý số lượng replica của Pod |
| **Service** | Expose Pod ra mạng nội bộ cluster |
| **Ingress** | Route HTTP từ bên ngoài vào Service |
| **PVC** | Yêu cầu dung lượng disk (Persistent Volume Claim) |
| **Namespace** | Không gian tên, tách biệt resource |
| **Operator** | Controller K8s quản lý ứng dụng phức tạp |
| **Manifest / YAML** | File khai báo resource K8s |

---

## Bước tiếp theo

→ Đọc [01-chuan-bi-moi-truong.md](01-chuan-bi-moi-truong.md) để cài đặt công cụ cần thiết.
