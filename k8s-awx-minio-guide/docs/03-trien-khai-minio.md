# 03 — Triển khai MinIO trên Kubernetes

Hướng dẫn chi tiết từng bước deploy MinIO, giải thích từng file manifest.

---

## Tổng quan

MinIO lab này gồm:

| File | Mục đích |
|------|----------|
| `namespace.yaml` | Tạo namespace `minio` |
| `secret.yaml` | Root user/password (⚠️ đổi khi production) |
| `pvc.yaml` | Disk 10Gi lưu dữ liệu |
| `deployment.yaml` | Pod chạy MinIO server |
| `service.yaml` | Expose port 9000 (API) và 9001 (Console) |
| `ingress.yaml` | Truy cập qua `minio.local` và `minio-api.local` |

---

## Bước 1: Xem credential mặc định

Mở `minio/secret.yaml`:

```yaml
# rootUser / rootPassword — tài khoản admin MinIO
# ⚠️ CHỈ DÙNG CHO HỌC TẬP — production phải đổi mật khẩu mạnh
stringData:
  rootUser: minioadmin
  rootPassword: minioadmin123
```

---

## Bước 2: Triển khai bằng script (khuyến nghị)

```bash
cd k8s-awx-minio-guide
./scripts/02-deploy-minio.sh
```

Script sẽ:
1. Apply từng manifest theo thứ tự
2. Chờ pod `Running`
3. In URL truy cập

---

## Bước 3: Triển khai thủ công (học từng lệnh)

```bash
# --- Bước 3.1: Tạo namespace ---
# apply -f — đọc file YAML và tạo/cập nhật resource trên cluster
kubectl apply -f minio/namespace.yaml

# --- Bước 3.2: Tạo Secret chứa password ---
kubectl apply -f minio/secret.yaml

# --- Bước 3.3: Tạo PVC (xin disk 10Gi) ---
kubectl apply -f minio/pvc.yaml

# Kiểm tra PVC đã Bound chưa (phải Bound trước khi pod start)
kubectl get pvc -n minio
# STATUS mong đợi: Bound

# --- Bước 3.4: Deploy MinIO pod ---
kubectl apply -f minio/deployment.yaml

# Chờ pod Running (timeout 120 giây)
kubectl wait --for=condition=ready pod \
  -l app=minio -n minio --timeout=120s

# --- Bước 3.5: Tạo Service ---
kubectl apply -f minio/service.yaml

# --- Bước 3.6: Tạo Ingress ---
kubectl apply -f minio/ingress.yaml

# --- Kiểm tra tổng thể ---
kubectl get all -n minio
```

---

## Bước 4: Truy cập MinIO Console

### Cách A — Qua Ingress (sau khi cấu hình /etc/hosts)

Mở browser: **http://minio.local**

- Username: `minioadmin`
- Password: `minioadmin123`

### Cách B — Port-forward (khi Ingress chưa hoạt động)

```bash
# Forward port 9001 (Console) ra localhost
# Giữ terminal này mở
kubectl port-forward svc/minio 9001:9001 -n minio

# Mở browser: http://localhost:9001
```

```bash
# Forward port 9000 (S3 API) — cần cho mc CLI và AWX
kubectl port-forward svc/minio 9000:9000 -n minio
```

---

## Bước 5: Dùng MinIO Client (`mc`)

```bash
# Thêm alias — đặt tên "local" cho server MinIO
# local — tên alias tuỳ chọn
# http://localhost:9000 — endpoint (dùng port-forward hoặc minio-api.local)
# minioadmin / minioadmin123 — access key / secret key
mc alias set local http://localhost:9000 minioadmin minioadmin123

# Kiểm tra kết nối
mc admin info local

# Tạo bucket tên "awx-projects" — dùng cho AWX sau này
mc mb local/awx-projects

# Liệt kê bucket
mc ls local

# Upload file thử
echo "Hello MinIO" > /tmp/test.txt
mc cp /tmp/test.txt local/awx-projects/

# Xem file trong bucket
mc ls local/awx-projects/
```

Hoặc chạy script demo:

```bash
./examples/minio/demo-upload.sh
```

---

## Bước 6: Hiểu Deployment YAML

Mở `minio/deployment.yaml` — các điểm quan trọng:

```yaml
spec:
  containers:
    - name: minio
      image: minio/minio:RELEASE.2024-12-18T13-15-44Z  # Pin version ổn định
      args:
        - server          # Chế độ server (không phải gateway)
        - /data           # Thư mục lưu data (mount từ PVC)
        - --console-address
        - ":9001"         # Port giao diện web Console
      env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:   # Đọc user từ Secret (không hardcode)
              name: minio-credentials
              key: rootUser
      volumeMounts:
        - name: data
          mountPath: /data  # Gắn PVC vào /data trong container
      livenessProbe:       # K8s tự restart nếu MinIO không phản hồi
        httpGet:
          path: /minio/health/live
          port: 9000
```

---

## Bước 7: Xử lý sự cố

### Pod Pending

```bash
kubectl describe pod -l app=minio -n minio
# Tìm dòng Events — thường là PVC chưa Bound
kubectl get pvc -n minio
```

### Pod CrashLoopBackOff

```bash
kubectl logs -l app=minio -n minio
# Lỗi phổ biến: permission denied trên /data → kiểm tra PVC mount
```

### Không login được Console

```bash
# Xác nhận secret đúng
kubectl get secret minio-credentials -n minio -o yaml
```

---

## Dọn dẹp (xoá MinIO)

```bash
# Xoá toàn bộ resource MinIO
kubectl delete -f minio/

# Hoặc xoá cả namespace (nhanh hơn)
kubectl delete namespace minio
```

---

## Bước tiếp theo

→ [04-trien-khai-awx.md](04-trien-khai-awx.md) — triển khai AWX sau khi MinIO đã chạy.
