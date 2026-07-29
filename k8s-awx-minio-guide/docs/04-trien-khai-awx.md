# 04 — Triển khai AWX trên Kubernetes

AWX được cài qua **AWX Operator**. Operator tự quản lý PostgreSQL, Redis, và các pod AWX.

---

## Tổng quan quy trình

```
Bước 1: Cài AWX Operator vào namespace awx
         ↓
Bước 2: Tạo AWX Custom Resource (awx-instance.yaml)
         ↓
Bước 3: Operator tự tạo PostgreSQL, Redis, AWX pods
         ↓
Bước 4: Lấy mật khẩu admin, truy cập Web UI
```

**Thời gian:** 10–15 phút (PostgreSQL init mất thời gian).

---

## Bước 1: Cài AWX Operator

### Cách A — Script tự động (khuyến nghị)

```bash
./scripts/03-deploy-awx-operator.sh
```

### Cách B — Thủ công từng lệnh

```bash
# --- 1.1: Tạo namespace awx ---
kubectl apply -f awx/namespace.yaml

# --- 1.2: Cài AWX Operator bằng Helm ---
# helm repo add — thêm repository chứa chart
helm repo add awx-operator https://ansible.github.io/awx-operator/
helm repo update

# helm install — cài operator vào namespace awx
# awx-operator — tên release
# awx-operator/awx-operator — chart name
# -n awx — namespace đích
# --create-namespace — tạo namespace nếu chưa có
helm install awx-operator awx-operator/awx-operator \
  -n awx \
  --create-namespace

# --- 1.3: Chờ Operator pod Running ---
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=awx-operator -n awx --timeout=180s

# Kiểm tra
kubectl get pods -n awx
```

---

## Bước 2: Tạo AWX Instance

```bash
# Apply Custom Resource — Operator sẽ "nhìn thấy" và bắt đầu tạo AWX
kubectl apply -f awx/awx-instance.yaml

# Theo dõi tiến trình (có thể mất 10+ phút)
# watch — lặp lệnh mỗi 2 giây (Ctrl+C để thoát)
watch kubectl get pods -n awx
```

Các pod sẽ xuất hiện lần lượt:

| Pod | Vai trò |
|-----|---------|
| `awx-operator-*` | Operator controller |
| `awx-postgres-*` | Database PostgreSQL |
| `awx-task-*` | Chạy Ansible jobs |
| `awx-web-*` | Giao diện web |

Hoặc dùng script:

```bash
./scripts/04-deploy-awx-instance.sh
```

---

## Bước 3: Kiểm tra AWX đã sẵn sàng

```bash
# Xem trạng thái AWX Custom Resource
kubectl get awx -n awx

# OUTPUT mong đợi khi cột conditions có "Running":
# NAME          AGE
# awx           5m

# Xem chi tiết (tìm URL và password)
kubectl get awx awx -n awx -o jsonpath='{.status}' | jq .
```

---

## Bước 4: Lấy mật khẩu admin

AWX tạo secret chứa password admin tự động:

```bash
# Lấy tên secret admin password
# jsonpath — trích xuất field cụ thể từ YAML/JSON output
kubectl get secret -n awx | grep admin-password

# Thường tên là: awx-admin-password
# Decode password:
kubectl get secret awx-admin-password -n awx \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

**Username mặc định:** `admin`

---

## Bước 5: Truy cập AWX Web UI

### Cách A — Ingress

```bash
kubectl apply -f awx/ingress.yaml
# Mở browser: http://awx.local
# Login: admin / <password từ bước 4>
```

### Cách B — Port-forward

```bash
# Forward port 8052 (AWX web) ra localhost
kubectl port-forward svc/awx-service 8052:80 -n awx

# Mở browser: http://localhost:8052
```

---

## Bước 6: Thiết lập AWX lần đầu

Sau khi đăng nhập, làm theo thứ tự:

### 6.1 Tạo Organization

```
AWX UI → Access → Organizations → Add
  Name: Default
  Description: Tổ chức mặc định cho lab
```

### 6.2 Tạo Credential (SSH hoặc Machine)

```
AWX UI → Access → Credentials → Add
  Name: local-machine
  Credential Type: Machine
  Username: <user macOS của bạn>
  SSH Private Key: (paste key nếu có)
```

### 6.3 Tạo Inventory

```
AWX UI → Resources → Inventories → Add
  Name: localhost
  Organization: Default
  Source: Manual
  → Hosts → Add: localhost (ansible_connection=local)
```

Thêm biến host cho localhost:

```yaml
# Trong AWX UI, edit host localhost, Variables:
ansible_connection: local
ansible_python_interpreter: /usr/bin/python3
```

### 6.4 Tạo Project (playbook từ Git)

```
AWX UI → Resources → Projects → Add
  Name: hello-world
  Organization: Default
  SCM Type: Git
  SCM URL: https://github.com/ansible/ansible-examples
  SCM Branch: master
  Playbook Directory: hello_world/
```

> Hoặc dùng playbook local trong `examples/ansible-playbook/` (xem docs/05).

### 6.5 Tạo Job Template

```
AWX UI → Resources → Templates → Add → Job Template
  Name: Hello World
  Job Type: Run
  Inventory: localhost
  Project: hello-world
  Playbook: hello_world/playbook.yml
  Credential: local-machine
```

Nhấn **Launch** để chạy thử!

---

## Hiểu file awx-instance.yaml

```yaml
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
  namespace: awx
spec:
  service_type: ClusterIP     # Service nội bộ, expose qua Ingress/port-forward
  ingress_type: none          # Tự quản lý Ingress riêng (awx/ingress.yaml)
  hostname: awx.local
  admin_user: admin
  # no_log: false             # Bật log chi tiết khi debug
  web_resource_requirements:
    requests:
      cpu: 250m
      memory: 512Mi
  task_resource_requirements:
    requests:
      cpu: 250m
      memory: 512Mi
  postgres_storage_class: ""  # Dùng StorageClass mặc định
  postgres_storage_requirements:
    requests:
      storage: 8Gi
```

---

## Xử lý sự cố

### AWX pod Pending / OOMKilled

```bash
kubectl describe pod -l app.kubernetes.io/name=awx-web -n awx
# Tăng RAM Docker Desktop lên 8GB+
```

### PostgreSQL pod không start

```bash
kubectl logs -l app.kubernetes.io/name=awx-postgres -n awx
kubectl get pvc -n awx
```

### Không lấy được admin password

```bash
# Liệt kê tất cả secret trong namespace awx
kubectl get secrets -n awx
kubectl get secret awx-admin-password -n awx -o yaml
```

---

## Dọn dẹp AWX

```bash
# Xoá AWX instance (Operator sẽ dọn pod liên quan)
kubectl delete -f awx/awx-instance.yaml

# Gỡ Operator
helm uninstall awx-operator -n awx

# Xoá namespace
kubectl delete namespace awx
```

---

## Bước tiếp theo

→ [05-tich-hop-awx-minio.md](05-tich-hop-awx-minio.md) — kết nối AWX với MinIO.
