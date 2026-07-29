# 01 — Chuẩn bị môi trường

Hướng dẫn cài đặt cluster Kubernetes local và các công cụ cần thiết.

---

## 1. Cài Docker Desktop (macOS / Windows)

Docker Desktop có sẵn Kubernetes single-node, phù hợp cho người mới.

### Bước cài

1. Tải tại: https://www.docker.com/products/docker-desktop/
2. Cài và mở Docker Desktop
3. Vào **Settings → Resources**:
   - RAM: **8 GB** trở lên (AWX cần nhiều RAM)
   - CPUs: **4** trở lên
   - Disk: **40 GB** trở lên
4. Vào **Settings → Kubernetes** → bật **Enable Kubernetes** → Apply

### Kiểm tra K8s đã sẵn sàng

```bash
# kubectl — công cụ CLI giao tiếp với cluster K8s
# "get nodes" — liệt kê các node (máy) trong cluster
# -o wide — hiển thị thêm IP, OS, kernel version
kubectl get nodes -o wide
```

Kết quả mong đợi: 1 node `Ready`, tên thường là `docker-desktop`.

```bash
# Kiểm tra StorageClass — cần để tạo PVC (disk cho MinIO, PostgreSQL)
# StorageClass mặc định của Docker Desktop: "hostpath"
kubectl get storageclass
```

---

## 2. Cài kubectl (nếu chưa có)

```bash
# macOS — dùng Homebrew
# brew install — cài package
brew install kubectl

# Kiểm tra phiên bản (nên ≥ 1.28)
kubectl version --client
```

---

## 3. Cài Helm (tuỳ chọn, khuyến nghị)

Helm giúp cài AWX Operator nhanh hơn so với apply YAML thủ công.

```bash
# macOS
brew install helm

# Kiểm tra
helm version
```

---

## 4. Cài MinIO Client (`mc`)

`mc` là CLI chính thức của MinIO, tương tự `aws s3` CLI.

```bash
# macOS — tải binary mc
brew install minio/stable/mc

# Kiểm tra
mc --version
```

---

## 5. Cấu hình `/etc/hosts`

Ingress lab dùng hostname local. Thêm vào file hosts:

```bash
# Mở file hosts (cần quyền sudo trên macOS/Linux)
# /etc/hosts — map tên miền → IP local
sudo sh -c 'cat >> /etc/hosts << EOF
127.0.0.1 minio.local minio-api.local awx.local
EOF'
```

Kiểm tra:

```bash
# ping — kiểm tra hostname resolve về 127.0.0.1
ping -c 1 awx.local
```

---

## 6. Cài Ingress Controller

Kubernetes không có Ingress sẵn — cần cài controller (nginx là phổ biến nhất).

```bash
# Apply manifest chính thức của NGINX Ingress Controller
# -f — đọc manifest từ URL
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml

# Chờ pod ingress-nginx sẵn sàng (có thể mất 1–2 phút)
# -n ingress-nginx — namespace của ingress controller
# -l — lọc theo label
# --timeout=120s — chờ tối đa 120 giây
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

Kiểm tra:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

---

## 7. Phương án B: minikube (Linux hoặc thay Docker Desktop)

```bash
# Cài minikube
brew install minikube

# Khởi động cluster với đủ tài nguyên
# --memory=8192 — 8 GB RAM
# --cpus=4 — 4 CPU
minikube start --memory=8192 --cpus=4

# Bật addon ingress
minikube addons enable ingress

# Chạy tunnel (giữ terminal mở) — cho phép truy cập LoadBalancer/Ingress từ localhost
minikube tunnel
```

Với minikube, thay `127.0.0.1` bằng IP minikube:

```bash
minikube ip
# Thêm IP đó vào /etc/hosts thay vì 127.0.0.1
```

---

## 8. Chạy script kiểm tra tự động

Repo có script kiểm tra toàn bộ yêu cầu:

```bash
cd k8s-awx-minio-guide
chmod +x scripts/01-check-prerequisites.sh
./scripts/01-check-prerequisites.sh
```

Script sẽ báo ✅ hoặc ❌ cho từng mục.

---

## Checklist trước khi sang bước tiếp

- [ ] `kubectl get nodes` → node `Ready`
- [ ] `kubectl get storageclass` → có StorageClass mặc định
- [ ] Ingress controller pod `Running`
- [ ] `/etc/hosts` đã thêm 3 hostname
- [ ] RAM Docker Desktop ≥ 8 GB

---

## Bước tiếp theo

→ Đọc [02-kubernetes-co-ban.md](02-kubernetes-co-ban.md) nếu bạn chưa quen K8s, hoặc nhảy thẳng [03-trien-khai-minio.md](03-trien-khai-minio.md).
