# 05 — Tích hợp AWX + MinIO

Hướng dẫn dùng MinIO làm object storage cho AWX: lưu playbook, artifact, và backup.

---

## Tại sao tích hợp?

| Use case | Mô tả |
|----------|-------|
| Project SCM | AWX lấy playbook từ S3 bucket thay vì Git |
| Artifact storage | Lưu output file sau job |
| Backup | Export project/inventory lên MinIO |

MinIO tương thích **100% S3 API** — AWX hỗ trợ S3 credential type.

---

## Bước 1: Chuẩn bị bucket trên MinIO

```bash
# Đảm bảo port-forward MinIO đang chạy (terminal riêng)
kubectl port-forward svc/minio 9000:9000 -n minio

# Cấu hình mc alias
mc alias set local http://localhost:9000 minioadmin minioadmin123

# Tạo bucket cho AWX
mc mb local/awx-projects      # Chứa playbook
mc mb local/awx-artifacts     # Chứa output job
mc mb local/awx-backups       # Backup cấu hình

# Upload playbook mẫu từ repo
mc cp --recursive examples/ansible-playbook/hello-world/ local/awx-projects/hello-world/

# Kiểm tra
mc ls local/awx-projects/
mc ls local/awx-projects/hello-world/
```

---

## Bước 2: Tạo S3 Credential trong AWX

```
AWX UI → Access → Credentials → Add

  Name: minio-s3
  Organization: Default
  Credential Type: Amazon S3  (hoặc "S3" tùy phiên bản AWX)

  AWS Access Key: minioadmin
  AWS Secret Key: minioadmin123
```

---

## Bước 3: Tạo Custom Credential cho MinIO endpoint

AWX mặc định trỏ tới AWS. Với MinIO cần set endpoint qua **Environment Variables** trong Job Template hoặc Custom Credential.

### Cách A — Thêm biến môi trường vào Job Template

```
AWX UI → Resources → Templates → Edit Job Template

  Extra Variables (YAML):
```

```yaml
# Biến môi trường cho boto3/aws cli trỏ về MinIO thay vì AWS
s3_endpoint: "http://minio.minio.svc.cluster.local:9000"
# minio.minio.svc.cluster.local — DNS nội bộ K8s, AWX pod gọi trực tiếp
# Không cần port-forward khi AWX và MinIO cùng cluster
```

### Cách B — Inject qua playbook

Trong playbook, dùng `amazon.aws.s3_object` với endpoint override:

```yaml
# examples/ansible-playbook/hello-world/playbook-with-s3.yml
- name: Upload artifact to MinIO
  hosts: localhost
  connection: local
  tasks:
    - name: Upload file to MinIO S3
      amazon.aws.s3_object:
        bucket: awx-artifacts
        object: "output/{{ ansible_date_time.iso8601 }}.txt"
        src: /tmp/result.txt
        mode: put
        aws_access_key: "{{ lookup('env', 'AWS_ACCESS_KEY_ID') }}"
        aws_secret_key: "{{ lookup('env', 'AWS_SECRET_ACCESS_KEY') }}"
        endpoint_url: "http://minio.minio.svc.cluster.local:9000"
      environment:
        AWS_ACCESS_KEY_ID: minioadmin
        AWS_SECRET_ACCESS_KEY: minioadmin123
```

---

## Bước 4: Tạo Project lấy playbook từ MinIO

AWX hỗ trợ SCM Type **"Manual"** hoặc custom script. Cách đơn giản nhất cho lab:

### Dùng Project SCM = Git (playbook sync từ repo)

Giữ project Git như docs/04, dùng MinIO chỉ để lưu **artifact**.

### Dùng Custom Inventory Script + S3

Nâng cao hơn — tạo **Custom Credential** + **Source Control** script pull từ S3.

Ví dụ script sync (chạy trên AWX task pod):

```bash
#!/bin/bash
# sync-from-minio.sh — chạy trước job để pull playbook từ MinIO
# $1 = bucket path

mc alias set awxminio http://minio.minio.svc.cluster.local:9000 \
  "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY"

mc cp --recursive "awxminio/awx-projects/$1/" /runner/project/
```

---

## Bước 5: Playbook upload artifact lên MinIO

Chạy playbook mẫu sau job chính:

```yaml
# Thêm vào cuối playbook hello-world
- name: Save job result to MinIO
  hosts: localhost
  connection: local
  tasks:
    - name: Write result file
      copy:
        content: "Job completed at {{ ansible_date_time.iso8601 }}"
        dest: /tmp/job-result.txt

    - name: Upload to MinIO via mc (nếu mc có trong execution environment)
      shell: |
        mc alias set local http://minio.minio.svc.cluster.local:9000 minioadmin minioadmin123
        mc cp /tmp/job-result.txt local/awx-artifacts/job-{{ awx_job_id | default('manual') }}.txt
      changed_when: true
```

Trong AWX Job Template, thêm **Extra Variable**:

```yaml
awx_job_id: "{{ awx_job_id }}"
```

---

## Bước 6: Kiểm tra kết nối AWX → MinIO từ trong cluster

Chạy pod test trong namespace awx:

```bash
# Tạo pod curl tạm thời để test kết nối nội bộ
kubectl run s3-test --rm -it --restart=Never \
  --image=minio/mc --namespace=awx -- \
  sh -c "
    mc alias set test http://minio.minio.svc.cluster.local:9000 minioadmin minioadmin123 && \
    mc ls test/awx-projects/
  "
```

Nếu thấy danh sách file → AWX task pod cũng kết nối được MinIO qua DNS nội bộ.

---

## Sơ đồ luồng dữ liệu

```
┌──────────────┐    pull playbook     ┌─────────────┐
│  MinIO       │ ◄─────────────────── │  AWX Task   │
│  awx-projects│                      │  Pod        │
└──────────────┘                      └──────┬──────┘
                                             │ chạy playbook
                                             ▼
                                      ┌─────────────┐
                                      │  Target     │
                                      │  hosts      │
                                      └──────┬──────┘
                                             │ upload artifact
                                             ▼
┌──────────────┐    push artifact     ┌─────────────┐
│  MinIO       │ ◄─────────────────── │  AWX Task   │
│  awx-artifacts                      │  Pod        │
└──────────────┘                      └─────────────┘
```

---

## Lưu ý bảo mật (production)

| Lab (OK) | Production (bắt buộc) |
|----------|----------------------|
| Password trong secret.yaml | Dùng Sealed Secrets / External Secrets |
| HTTP (không TLS) | Bật TLS cho MinIO và AWX Ingress |
| Root user MinIO | Tạo IAM policy user riêng cho AWX |
| Single node MinIO | MinIO distributed mode (≥ 4 node) |

---

## Bước tiếp theo

→ [06-bai-tap-thuc-hanh.md](06-bai-tap-thuc-hanh.md) — bài tập tổng hợp.
