# 02 — Kubernetes cơ bản (cho lab AWX & MinIO)

Tài liệu này giải thích các khái niệm K8s **đủ dùng** cho lab — không đi sâu toàn bộ K8s.

---

## Namespace — Tách biệt môi trường

Namespace giống "thư mục" logic trong cluster.

```bash
# Tạo namespace tên "minio"
kubectl create namespace minio

# Liệt kê namespace
kubectl get namespaces
# Viết tắt: kubectl get ns
```

Lab này dùng 2 namespace:

| Namespace | Chứa |
|-----------|------|
| `minio` | MinIO server + PVC |
| `awx` | AWX Operator + AWX instance + PostgreSQL |

---

## Pod — Container đang chạy

```bash
# Xem pod trong namespace minio
# -n minio — chỉ định namespace
kubectl get pods -n minio

# Xem chi tiết pod (events, lỗi mount volume...)
kubectl describe pod <tên-pod> -n minio

# Xem log container trong pod
# -f — follow (stream log realtime, Ctrl+C để thoát)
kubectl logs -f <tên-pod> -n minio
```

**Trạng thái pod thường gặp:**

| Status | Ý nghĩa |
|--------|---------|
| `Running` | ✅ Đang chạy bình thường |
| `Pending` | ⏳ Chưa schedule được (thiếu resource/PVC) |
| `CrashLoopBackOff` | ❌ Container crash liên tục — xem log |
| `ImagePullBackOff` | ❌ Không pull được image — kiểm tra mạng |

---

## Deployment — Quản lý Pod

Deployment đảm bảo luôn có N bản copy pod đang chạy.

```yaml
# Ví dụ rút gọn (xem minio/deployment.yaml để biết đầy đủ)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio
spec:
  replicas: 1          # Số pod muốn chạy
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
        - name: minio
          image: minio/minio:latest
```

```bash
# Apply manifest — tạo hoặc cập nhật resource
kubectl apply -f minio/deployment.yaml

# Xem deployment
kubectl get deployment -n minio

# Restart deployment (rolling restart tất cả pod)
kubectl rollout restart deployment/minio -n minio
```

---

## Service — Kết nối nội bộ

Pod có IP thay đổi khi restart. Service cung cấp **IP/DNS ổn định**.

| Loại Service | Dùng khi |
|--------------|----------|
| `ClusterIP` | Chỉ truy cập trong cluster (mặc định) |
| `NodePort` | Expose qua port trên node |
| `LoadBalancer` | Cloud LB (EKS, GKE...) |

```bash
# Xem service
kubectl get svc -n minio

# Test kết nối từ pod khác trong cluster
kubectl run curl-test --rm -it --image=curlimages/curl -- \
  curl -s http://minio.minio.svc.cluster.local:9000/minio/health/live
# minio.minio.svc.cluster.local = DNS nội bộ K8s
# Cú pháp: <service>.<namespace>.svc.cluster.local
```

---

## PVC — Lưu trữ bền vững

Pod mất dữ liệu khi restart nếu không gắn volume. PVC xin disk từ cluster.

```bash
# Xem PVC
kubectl get pvc -n minio

# Nếu STATUS = Pending → StorageClass chưa sẵn sàng
kubectl describe pvc minio-data -n minio
```

---

## Secret — Lưu mật khẩu an toàn

Không hardcode password trong Deployment. Dùng Secret:

```bash
# Xem secret (giá trị được encode base64)
kubectl get secret minio-credentials -n minio

# Decode password (chỉ dùng khi học tập!)
kubectl get secret minio-credentials -n minio \
  -o jsonpath='{.data.rootPassword}' | base64 -d && echo
```

---

## Ingress — Truy cập từ browser

Ingress route HTTP request từ bên ngoài vào Service.

```bash
# Xem ingress
kubectl get ingress -n minio

# Mô tả chi tiết (xem backend service, host rule)
kubectl describe ingress minio-console -n minio
```

Flow:

```
Browser → awx.local:80 → Ingress Controller → Service awx-service → Pod AWX
```

---

## Các lệnh kubectl hữu ích nhất

```bash
# === THÔNG TIN ===
kubectl get all -n minio              # Pod, Service, Deployment cùng lúc
kubectl get events -n minio --sort-by='.lastTimestamp'  # Sự kiện gần nhất

# === DEBUG ===
kubectl describe pod <pod> -n minio   # Chi tiết + events lỗi
kubectl logs <pod> -n minio           # Log container
kubectl exec -it <pod> -n minio -- sh # Vào shell trong container

# === QUẢN LÝ ===
kubectl apply -f minio/               # Apply tất cả manifest trong thư mục
kubectl delete -f minio/              # Xoá tất cả resource đã tạo
kubectl delete namespace minio        # Xoá cả namespace (cẩn thận!)

# === PORT-FORWARD (khi Ingress chưa hoạt động) ===
# Map port local → port trong pod
kubectl port-forward svc/minio 9000:9000 -n minio
# Truy cập: http://localhost:9000
```

---

## Apply manifest theo thứ tự

Luôn apply theo thứ tự phụ thuộc:

```
1. namespace.yaml   ← tạo namespace trước
2. secret.yaml      ← credential trước deployment
3. pvc.yaml         ← disk trước pod cần mount
4. deployment.yaml  ← pod cần secret + pvc
5. service.yaml     ← expose pod
6. ingress.yaml     ← route từ bên ngoài
```

Script `02-deploy-minio.sh` tự apply đúng thứ tự này.

---

## Bước tiếp theo

→ [03-trien-khai-minio.md](03-trien-khai-minio.md) — triển khai MinIO thực tế.
