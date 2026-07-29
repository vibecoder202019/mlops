# Hướng dẫn triển khai AWX & MinIO trên Kubernetes

Repo tự học dành cho **người mới bắt đầu**, hướng dẫn từng bước triển khai:

- **AWX** — giao diện web quản lý Ansible (Automation Controller mã nguồn mở)
- **MinIO** — object storage tương thích S3 (lưu artifact, backup, file playbook)

Tất cả chạy trên **Kubernetes** với manifest YAML và script shell có **comment tiếng Việt** giải thích từng lệnh.

---

## Bạn sẽ học được gì?

| Chủ đề | Nội dung |
|--------|----------|
| Kubernetes cơ bản | Namespace, Pod, Deployment, Service, PVC, Ingress |
| MinIO | Cài đặt, tạo bucket, dùng `mc` CLI, truy cập qua API S3 |
| AWX | Cài AWX Operator, tạo AWX instance, đăng nhập, chạy Job Template |
| Python + AWX | Script module, custom module, AWX REST API, Execution Environment |
| Tích hợp | Dùng MinIO làm nơi lưu project/artifact cho AWX |
| Vận hành | Kiểm tra health, xem log, backup cơ bản |

---

## Yêu cầu trước khi bắt đầu

| Công cụ | Phiên bản gợi ý | Mục đích |
|---------|-----------------|----------|
| Docker Desktop hoặc minikube | Mới nhất | Cluster K8s local |
| kubectl | ≥ 1.28 | Quản lý cluster |
| helm | ≥ 3.12 | Cài AWX Operator (tuỳ chọn) |
| git | Bất kỳ | Clone repo |

**Tài nguyên tối thiểu (máy local):** 8 GB RAM, 4 CPU, 40 GB disk.

---

## Cấu trúc repo

```
k8s-awx-minio-guide/
├── README.md                          # File này — điểm bắt đầu
├── docs/                              # Lý thuyết + hướng dẫn chi tiết
│   ├── 00-gioi-thieu.md
│   ├── 01-chuan-bi-moi-truong.md
│   ├── 02-kubernetes-co-ban.md
│   ├── 03-trien-khai-minio.md
│   ├── 04-trien-khai-awx.md
│   ├── 05-tich-hop-awx-minio.md
│   ├── 06-bai-tap-thuc-hanh.md
│   └── 07-tich-hop-awx-python.md
├── minio/                             # Manifest Kubernetes cho MinIO
│   ├── namespace.yaml
│   ├── secret.yaml
│   ├── pvc.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── awx/                               # Manifest Kubernetes cho AWX
│   ├── namespace.yaml
│   ├── awx-instance.yaml
│   └── ingress.yaml
├── scripts/                           # Script tự động hoá (có comment)
│   ├── 01-check-prerequisites.sh
│   ├── 02-deploy-minio.sh
│   ├── 03-deploy-awx-operator.sh
│   ├── 04-deploy-awx-instance.sh
│   └── 05-verify-all.sh
└── examples/                          # Ví dụ Ansible, MinIO & Python
    ├── ansible-playbook/
    │   ├── hello-world/
    │   └── python-demo/               # Playbook Python cho AWX
    ├── python/                        # AWX API client + scripts
    │   ├── awx_client.py
    │   ├── launch_job.py
    │   ├── scripts/
    │   └── library/
    └── minio/
        └── demo-upload.sh
```

---

## Lộ trình học (khuyến nghị)

```
Tuần 1: Chuẩn bị + K8s cơ bản
  └── docs/00 → docs/02, chạy scripts/01-check-prerequisites.sh

Tuần 2: Triển khai MinIO
  └── docs/03, chạy scripts/02-deploy-minio.sh
  └── Thực hành: tạo bucket, upload file qua mc CLI

Tuần 3: Triển khai AWX
  └── docs/04, chạy scripts/03 → 04
  └── Đăng nhập AWX, tạo Organization, Project, Job Template

Tuần 4: Tích hợp + bài tập
  └── docs/05 → docs/07
  └── Chạy playbook mẫu, lưu artifact lên MinIO
  └── Python: launch job AWX qua API
```

---

## Bắt đầu nhanh (Quick Start)

```bash
# 1. Clone repo (hoặc cd vào thư mục này nếu đã có)
cd k8s-awx-minio-guide

# 2. Kiểm tra môi trường — script sẽ báo thiếu gì
chmod +x scripts/*.sh examples/minio/demo-upload.sh
./scripts/01-check-prerequisites.sh

# 3. Triển khai MinIO (khoảng 2–3 phút)
./scripts/02-deploy-minio.sh

# 4. Triển khai AWX Operator + AWX instance (khoảng 10–15 phút)
./scripts/03-deploy-awx-operator.sh
./scripts/04-deploy-awx-instance.sh

# 5. Kiểm tra mọi thứ đã chạy
./scripts/05-verify-all.sh
```

---

## Truy cập sau khi cài

| Dịch vụ | URL mặc định (local) | Ghi chú |
|---------|----------------------|---------|
| MinIO Console | http://minio.local | User/pass xem `minio/secret.yaml` |
| MinIO API (S3) | http://minio-api.local:9000 | Dùng cho AWX / mc CLI |
| AWX Web UI | http://awx.local | Lấy mật khẩu admin: xem docs/04 |

> **Lưu ý:** Thêm vào `/etc/hosts` trên máy bạn:
> ```
> 127.0.0.1 minio.local minio-api.local awx.local
> ```
> Nếu dùng minikube, chạy `minikube tunnel` hoặc `kubectl port-forward` (chi tiết trong docs).

---

## Tài liệu chi tiết

Đọc theo thứ tự trong thư mục [`docs/`](docs/):

1. [Giới thiệu AWX & MinIO](docs/00-gioi-thieu.md)
2. [Chuẩn bị môi trường](docs/01-chuan-bi-moi-truong.md)
3. [Kubernetes cơ bản cho lab này](docs/02-kubernetes-co-ban.md)
4. [Triển khai MinIO](docs/03-trien-khai-minio.md)
5. [Triển khai AWX](docs/04-trien-khai-awx.md)
6. [Tích hợp AWX + MinIO](docs/05-tich-hop-awx-minio.md)
7. [Tích hợp AWX + Python](docs/07-tich-hop-awx-python.md)
8. [Bài tập thực hành](docs/06-bai-tap-thuc-hanh.md)

---

## Xử lý sự cố thường gặp

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|-------------|------------------------|------------|
| Pod `Pending` | Thiếu PVC / StorageClass | `kubectl get pvc -A`, bật storage trong Docker Desktop |
| AWX pod restart liên tục | Chưa đủ RAM | Tăng RAM Docker Desktop lên ≥ 8 GB |
| Không vào được awx.local | Ingress chưa hoạt động | Dùng `kubectl port-forward` (xem docs/04) |
| MinIO login fail | Secret chưa apply | `kubectl apply -f minio/secret.yaml` |

---

## Tài liệu tham khảo chính thức

- [AWX Operator Documentation](https://ansible.readthedocs.io/projects/awx-operator/)
- [AWX REST API](https://ansible.readthedocs.io/projects/awx/en/latest/rest_api/index.html)
- [Ansible Python Module Development](https://docs.ansible.com/ansible/latest/dev_guide/developing_modules_general.html)
- [MinIO Kubernetes Documentation](https://min.io/docs/minio/kubernetes/upstream/index.html)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)

---

## Giấy phép

Tài liệu và manifest trong repo này dùng cho mục đích học tập. AWX và MinIO tuân theo giấy phép riêng của từng dự án.
