# 06 — Bài tập thực hành

Các bài tập theo mức độ từ dễ → khó. Làm tuần tự để củng cố kiến thức.

---

## Bài 1 — Kiểm tra môi trường (⭐ Dễ)

**Mục tiêu:** Xác nhận cluster K8s và công cụ đã sẵn sàng.

```bash
# Chạy script kiểm tra
./scripts/01-check-prerequisites.sh

# Tự kiểm tra thêm:
kubectl get nodes
kubectl get storageclass
kubectl get pods -n ingress-nginx
```

**Kết quả mong đợi:** Tất cả ✅, node `Ready`, ingress pod `Running`.

---

## Bài 2 — Triển khai MinIO (⭐ Dễ)

**Mục tiêu:** Deploy MinIO và tạo bucket bằng tay.

```bash
# Triển khai
./scripts/02-deploy-minio.sh

# Kiểm tra pod
kubectl get pods -n minio

# Port-forward và tạo bucket
kubectl port-forward svc/minio 9000:9000 -n minio &
mc alias set local http://localhost:9000 minioadmin minioadmin123
mc mb local/bai-tap-02
mc ls local
```

**Câu hỏi tự kiểm tra:**
1. PVC có status `Bound` không? Tại sao cần PVC?
2. Port 9000 và 9001 khác nhau thế nào?

---

## Bài 3 — Upload và download file (⭐ Dễ)

**Mục tiêu:** Thao tác object storage cơ bản.

```bash
# Tạo file và upload
echo "Bai tap 03 - $(date)" > /tmp/baitap03.txt
mc cp /tmp/baitap03.txt local/bai-tap-02/

# Download về
mc cp local/bai-tap-02/baitap03.txt /tmp/downloaded.txt
cat /tmp/downloaded.txt

# Xoá object
mc rm local/bai-tap-02/baitap03.txt
mc ls local/bai-tap-02/
```

**Chạy script demo:**
```bash
./examples/minio/demo-upload.sh
```

---

## Bài 4 — Triển khai AWX (⭐⭐ Trung bình)

**Mục tiêu:** Cài AWX Operator và AWX instance, đăng nhập Web UI.

```bash
./scripts/03-deploy-awx-operator.sh
./scripts/04-deploy-awx-instance.sh

# Chờ tất cả pod Running
watch kubectl get pods -n awx

# Lấy password
kubectl get secret awx-admin-password -n awx \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Port-forward
kubectl port-forward svc/awx-service 8052:80 -n awx
# Truy cập http://localhost:8052 — login admin
```

**Câu hỏi tự kiểm tra:**
1. Operator khác Deployment thường thế nào?
2. Tại sao AWX cần PostgreSQL riêng?

---

## Bài 5 — Chạy Job Template đầu tiên (⭐⭐ Trung bình)

**Mục tiêu:** Tạo Organization, Inventory, Project, Job Template và chạy playbook.

**Các bước trong AWX UI:**

1. **Organization:** `Default`
2. **Inventory:** `localhost` với host `localhost`, variables:
   ```yaml
   ansible_connection: local
   ```
3. **Project:** SCM Type = Manual, hoặc Git URL:
   ```
   https://github.com/geerlingguy/ansible-for-devops-manual-setup
   ```
4. **Job Template:** Playbook `main.yml`, Inventory `localhost`
5. Nhấn **Launch** → xem output job

**Playbook local (tuỳ chọn):**

Upload playbook trong repo lên AWX bằng cách tạo Project Manual và sync từ Git repo này:

```
SCM URL: <url repo k8s-awx-minio-guide>
SCM Type: Git
Playbook: examples/ansible-playbook/hello-world/playbook.yml
```

---

## Bài 6 — Tích hợp MinIO + AWX (⭐⭐⭐ Nâng cao)

**Mục tiêu:** Upload playbook lên MinIO, chạy job AWX, lưu kết quả về MinIO.

```bash
# 1. Upload playbook lên MinIO
mc cp examples/ansible-playbook/hello-world/playbook.yml \
  local/awx-projects/hello-world/

# 2. Trong AWX: tạo S3 Credential (minio-s3)
#    Access Key: minioadmin
#    Secret Key: minioadmin123

# 3. Chạy pod test kết nối
kubectl run s3-test --rm -it --restart=Never \
  --image=minio/mc --namespace=awx -- \
  sh -c "mc alias set t http://minio.minio.svc.cluster.local:9000 minioadmin minioadmin123 && mc ls t/awx-projects/"

# 4. Sau khi job AWX chạy xong, upload artifact thủ công:
echo "Job done" > /tmp/artifact.txt
mc cp /tmp/artifact.txt local/awx-artifacts/
mc ls local/awx-artifacts/
```

---

## Bài 7 — Debug sự cố (⭐⭐⭐ Nâng cao)

**Mục tiêu:** Tự xử lý lỗi thường gặp.

### Tình huống A: Pod MinIO Pending

```bash
# Gợi ý: xem events
kubectl describe pod -l app=minio -n minio | tail -20
# Fix: kiểm tra PVC, StorageClass
```

### Tình huống B: AWX web không load

```bash
kubectl get pods -n awx
kubectl logs -l app.kubernetes.io/name=awx-web -n awx --tail=50
kubectl port-forward svc/awx-service 8052:80 -n awx
```

### Tình huống C: Job AWX failed

Trong AWX UI → Jobs → click job failed → xem **Standard Out** và **Standard Error**.

---

## Bài 8 — Dọn dẹp và triển khai lại (⭐⭐ Trung bình)

**Mục tiêu:** Hiểu lifecycle resource K8s.

```bash
# Xoá AWX
kubectl delete -f awx/awx-instance.yaml
helm uninstall awx-operator -n awx

# Xoá MinIO
kubectl delete namespace minio

# Triển khai lại từ đầu
./scripts/02-deploy-minio.sh
./scripts/03-deploy-awx-operator.sh
./scripts/04-deploy-awx-instance.sh
./scripts/05-verify-all.sh
```

---

## Bài 9 — Python + AWX (⭐⭐ Trung bình)

**Mục tiêu:** Chạy Python script trong playbook AWX và gọi AWX API từ Python.

### Phần A: Python trong Playbook

```bash
# Test script local trước
python3 examples/python/scripts/process_data.py --name "Lab 09"

# Trên AWX UI: tạo Job Template
#   Project: python-demo
#   Playbook: playbook-script.yml
#   Extra Variables: {"user_name": "Học viên"}
# Launch job → xem stdout có JSON output
```

**Câu hỏi tự kiểm tra:**
1. `script` module khác `command python3` thế nào?
2. Làm sao parse JSON từ stdout trong Ansible?

### Phần B: Gọi AWX API từ Python

```bash
# Port-forward AWX
kubectl port-forward svc/awx-service 8052:80 -n awx &

# Tạo token trên AWX UI → User → Tokens
export AWX_URL="http://localhost:8052"
export AWX_TOKEN="your-token"

# Setup Python venv
cd examples/python
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Liệt kê Job Template
python awx_client.py list-templates

# Launch job và đợi kết quả
python launch_job.py --template-name "Python Hello World" --wait
```

**Chạy demo tự động:**
```bash
./examples/python/run_demo.sh
```

---

## Bài 10 — Python + AWX + MinIO (⭐⭐⭐ Nâng cao)

**Mục tiêu:** Pipeline đầy đủ — Python tạo report → upload MinIO → trigger từ API.

```bash
# 1. Đảm bảo MinIO bucket awx-artifacts tồn tại
mc mb local/awx-artifacts 2>/dev/null || true

# 2. Trên AWX: Job Template "Python MinIO Demo"
#    Playbook: playbook-minio-python.yml
#    (Cần boto3 — xem execution-environment.yml)

# 3. Launch từ Python API
python launch_job.py --template-name "Python MinIO Demo" --wait

# 4. Kiểm tra file trên MinIO
mc ls local/awx-artifacts/reports/
```

---

## Checklist hoàn thành khóa học

- [ ] Giải thích được Pod, Service, Ingress, PVC
- [ ] Triển khai MinIO và thao tác bucket bằng `mc`
- [ ] Triển khai AWX bằng Operator
- [ ] Tạo và chạy Job Template thành công
- [ ] Kết nối AWX với MinIO qua DNS nội bộ cluster
- [ ] Chạy Python script trong playbook AWX
- [ ] Launch job AWX từ Python qua REST API
- [ ] Debug được pod Pending / CrashLoopBackOff
- [ ] Dọn dẹp và deploy lại từ đầu

---

## Tài nguyên mở rộng

| Chủ đề | Link |
|--------|------|
| AWX Operator | https://ansible.readthedocs.io/projects/awx-operator/ |
| MinIO K8s | https://min.io/docs/minio/kubernetes/upstream/index.html |
| Ansible Playbook | https://docs.ansible.com/ansible/latest/playbook_guide/ |
| Kubernetes Basics | https://kubernetes.io/docs/tutorials/kubernetes-basics/ |

Chúc mừng bạn đã hoàn thành lab! 🎉
