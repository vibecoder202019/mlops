# 07 — Tích hợp AWX với Python

Hướng dẫn dùng Python cùng AWX theo **3 hướng** phổ biến — phù hợp người mới bắt đầu.

---

## Tổng quan 3 hướng tích hợp

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWX + Python — 3 hướng                       │
├─────────────────┬─────────────────────┬─────────────────────────┤
│ 1. Trong        │ 2. Gọi AWX API      │ 3. Execution Environment│
│    Playbook     │    từ Python        │    (Python packages)    │
├─────────────────┼─────────────────────┼─────────────────────────┤
│ script module   │ requests / httpx    │ pip install trong EE    │
│ custom module   │ launch Job Template │ boto3, pandas, ...      │
│ ansible.builtin │ poll job status     │ requirements.txt        │
│ .command python3│                     │                         │
└─────────────────┴─────────────────────┴─────────────────────────┘
```

| Hướng | Khi nào dùng |
|-------|--------------|
| **Python trong Playbook** | Logic xử lý data, gọi API, transform file trong job AWX |
| **Python gọi AWX API** | CI/CD, script tự động trigger job, dashboard |
| **Execution Environment** | Cần thư viện Python ngoài (boto3, requests, pandas) |

---

## Phần A — Python trong Ansible Playbook (chạy trên AWX)

### A.1 Dùng `script` module

Module `script` copy file Python lên target host và chạy — **không cần** Python trên remote nếu `connection: local`.

```yaml
# examples/ansible-playbook/python-demo/playbook-script.yml
- name: Chạy Python script qua Ansible
  hosts: localhost
  connection: local
  tasks:
    - name: Execute Python script
      script: scripts/process_data.py
      # script module tự truyền arg nếu cần:
      # script: scripts/process_data.py --input /tmp/data.json
      register: python_result

    - name: Hiển thị kết quả
      debug:
        var: python_result.stdout
```

Script mẫu: `examples/python/scripts/process_data.py`

### A.2 Dùng `command` / `shell` với inline Python

Phù hợp cho đoạn code ngắn:

```yaml
- name: Chạy Python inline
  hosts: localhost
  connection: local
  tasks:
    - name: Tính toán bằng Python
      command: python3 -c "print(sum(range(1, 101)))"
      register: calc

    - name: In kết quả
      debug:
        msg: "Tổng 1-100 = {{ calc.stdout }}"
```

### A.3 Dùng `ansible.builtin.python`-style custom module

Custom module Python nằm trong `library/` của project:

```
examples/ansible-playbook/python-demo/
├── playbook-custom-module.yml
├── library/
│   └── hello_python.py      # Custom module
└── scripts/
    └── process_data.py
```

Chạy trên AWX:
1. Tạo **Project** trỏ tới repo/thư mục chứa playbook
2. **Job Template** → Playbook: `playbook-custom-module.yml`
3. AWX tự tìm module trong `library/`

---

## Phần B — Gọi AWX REST API từ Python

AWX expose REST API tại `/api/v2/`. Dùng Python để tự động hoá bên ngoài AWX.

### B.1 Lấy API Token

**Cách 1 — Qua Web UI:**

```
AWX UI → người dùng (góc phải) → Tokens → Create Token
  Description: python-client
  Scope: write (hoặc read nếu chỉ xem)
  → Copy token (chỉ hiện 1 lần!)
```

**Cách 2 — Qua CLI trong cluster:**

```bash
# Port-forward AWX
kubectl port-forward svc/awx-service 8052:80 -n awx

# Lấy token bằng username/password
curl -s -k -X POST http://localhost:8052/api/v2/tokens/ \
  -u admin:YOUR_PASSWORD \
  -H "Content-Type: application/json" \
  -d '{"description": "python-lab", "scope": "write"}' | python3 -m json.tool
```

Lưu token vào biến môi trường:

```bash
# export — đặt biến môi trường cho session terminal hiện tại
export AWX_URL="http://localhost:8052"
export AWX_TOKEN="your-token-here"
```

### B.2 Cài thư viện Python

```bash
cd k8s-awx-minio-guide/examples/python

# python3 -m venv — tạo virtual environment cô lập dependency
python3 -m venv .venv
source .venv/bin/activate

# pip install — cài package từ requirements.txt
pip install -r requirements.txt
```

### B.3 Client Python đơn giản

File `examples/python/awx_client.py` — wrapper AWX API có comment đầy đủ.

```bash
# Liệt kê Job Template
python awx_client.py list-templates

# Launch job template id=7
python awx_client.py launch --template-id 7

# Launch kèm extra variables
python awx_client.py launch --template-id 7 --extra-vars '{"env": "lab"}'

# Xem trạng thái job
python awx_client.py job-status --job-id 42
```

### B.4 Luồng launch job từ Python

```
Python script                    AWX API                    AWX Task Pod
     │                              │                            │
     │  POST /api/v2/job_templates/ │                            │
     │  {id}/launch/                │                            │
     ├─────────────────────────────►│                            │
     │                              │  Tạo Job, queue playbook   │
     │  ◄── { "job": 42 }           ├───────────────────────────►│
     │                              │                            │
     │  GET /api/v2/jobs/42/        │                            │
     │  (poll mỗi 5s)               │                            │
     ├─────────────────────────────►│                            │
     │  ◄── { "status": "successful" }                           │
```

Script mẫu: `examples/python/launch_job.py`

---

## Phần C — Execution Environment (EE) với Python

Mặc định AWX dùng EE `quay.io/ansible/awx-ee:latest` — đã có Python + Ansible core.

### C.1 Khi cần thêm package Python

Tạo `execution-environment.yml`:

```yaml
# examples/python/execution-environment.yml
version: 3
images:
  base_image:
    name: quay.io/ansible/awx-ee:latest
dependencies:
  python:
    - boto3          # AWS/MinIO S3
    - requests       # HTTP client
    - pandas         # xử lý data
  system:
    - mc             # MinIO client (tuỳ chọn)
```

Build EE (cần `ansible-builder`):

```bash
# Cài ansible-builder
pip install ansible-builder

# Build image EE
ansible-builder build -f execution-environment.yml -t my-awx-ee:latest

# Load vào cluster local (Docker Desktop)
docker save my-awx-ee:latest | docker load
```

Trong AWX UI → **Administration → Execution Environments → Add**:
- Name: `my-python-ee`
- Image: `my-awx-ee:latest`
- Pull: Never (local image)

Gán EE vào Job Template → **Execution Environment** = `my-python-ee`.

### C.2 Lab đơn giản không build EE

Với lab local, dùng EE mặc định + playbook cài package tạm:

```yaml
- name: Cài requests tạm (chỉ cho lab — production dùng EE)
  pip:
    name: requests
    state: present
  become: yes
```

> ⚠️ Production: luôn build EE riêng, không pip install lúc runtime.

---

## Phần D — Tích hợp Python + AWX + MinIO

Playbook kết hợp cả 3: Python xử lý data → upload MinIO → trigger từ script Python bên ngoài.

### D.1 Playbook Python upload MinIO

File: `examples/ansible-playbook/python-demo/playbook-minio-python.yml`

```yaml
- name: Python xử lý data và upload MinIO
  hosts: localhost
  connection: local
  vars:
    minio_endpoint: "http://minio.minio.svc.cluster.local:9000"
  tasks:
    - name: Chạy script Python tạo report
      script: scripts/generate_report.py
      register: report

    - name: Upload report lên MinIO
      script: scripts/upload_to_minio.py
      environment:
        MINIO_ENDPOINT: "{{ minio_endpoint }}"
        MINIO_ACCESS_KEY: minioadmin
        MINIO_SECRET_KEY: minioadmin123
        REPORT_FILE: "{{ report.stdout | trim }}"
```

### D.2 Script Python trigger job + đợi kết quả

```bash
# Chạy full workflow: launch AWX job → poll → in kết quả
export AWX_URL="http://localhost:8052"
export AWX_TOKEN="your-token"
python launch_job.py --template-name "Python MinIO Demo" --wait
```

---

## Phần E — Thiết lập trên AWX UI

### E.1 Tạo Project cho playbook Python

```
Resources → Projects → Add
  Name: python-demo
  Organization: Default
  SCM Type: Git (hoặc Manual sync)
  SCM URL: <url repo k8s-awx-minio-guide>
  Playbook Directory: examples/ansible-playbook/python-demo/
```

### E.2 Tạo Job Template

```
Resources → Templates → Add → Job Template
  Name: Python Hello World
  Job Type: Run
  Inventory: localhost
  Project: python-demo
  Playbook: playbook-script.yml
  Credential: (local machine nếu cần)
```

### E.3 Tạo Survey (input động từ UI)

Thêm **Survey** vào Job Template để truyền biến vào Python:

```
Template → Survey → Add
  Variable: user_name
  Type: Text
  Default: "Học viên AWX"
```

Playbook nhận biến:

```yaml
- debug:
    msg: "Xin chào {{ user_name }}!"
```

Launch từ Python kèm survey vars:

```python
client.launch_job(template_id=7, extra_vars={"user_name": "Python API"})
```

---

## Cấu trúc thư mục examples/python

```
examples/python/
├── requirements.txt           # requests, urllib3
├── awx_client.py              # Client AWX API (CLI + import)
├── launch_job.py              # Launch job và poll status
├── list_resources.py          # Liệt kê templates, inventories
├── execution-environment.yml  # EE mẫu (nâng cao)
├── scripts/
│   ├── process_data.py        # Script cho Ansible script module
│   ├── generate_report.py     # Tạo file report
│   └── upload_to_minio.py     # Upload S3 bằng boto3
└── library/
    └── hello_python.py        # Custom Ansible module
```

---

## Xử lý sự cố

| Lỗi | Nguyên nhân | Cách fix |
|-----|-------------|----------|
| `ModuleNotFoundError: requests` | EE thiếu package | Build EE hoặc pip trong playbook (lab) |
| `401 Unauthorized` API | Token hết hạn/sai | Tạo token mới |
| `python3: command not found` | EE hoặc host thiếu Python | Dùng EE mặc định + `connection: local` |
| Script module fail | Script thiếu shebang | Thêm `#!/usr/bin/env python3` đầu file |
| Custom module not found | Sai đường dẫn library/ | Đặt module trong `library/` cùng project |

---

## Bước tiếp theo

→ Làm bài tập Python trong [06-bai-tap-thuc-hanh.md](06-bai-tap-thuc-hanh.md#bài-9--python--awx--dễ)

→ Chạy demo: `./examples/python/run_demo.sh`
