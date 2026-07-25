# MLOps & AI Platform Labs

Lộ trình thực hành MLOps / AI Platform Engineer trên AWS + Kubernetes.

**GitHub:** [vibecoder202019/mlops](https://github.com/vibecoder202019/mlops)

## Cấu trúc repo

```
mlops/
├── docs/                          # Tài liệu hướng dẫn
│   ├── MLOPS-AI-PLATFORM-LABS-GUIDE.md   # Kiến thức + 10 labs
│   └── MLOPS-LABS-CICD-GUIDE.md          # CI/CD cho tất cả labs
├── labs/
│   ├── lab01/                     # Train & serve Iris classifier
│   ├── lab02/                     # GPU & AI workload
│   ├── lab03/                     # End-to-end MLOps pipeline
│   ├── lab04/                     # Data & model validation
│   ├── lab05/                     # KServe trên EKS
│   ├── lab06/                     # Kubeflow Pipeline
│   ├── lab07/                     # Cost optimization
│   ├── lab08/                     # vLLM self-hosted LLM
│   ├── lab09/                     # RAG platform infrastructure
│   └── lab10/                     # Fine-tuning MLOps
├── .github/workflows/             # GitHub Actions CI/CD
└── scripts/                       # quality-gate, smoke-test, cost-check
```

## Bắt đầu nhanh

### 1. Đọc tài liệu

```bash
open docs/MLOPS-AI-PLATFORM-LABS-GUIDE.md
```

### 2. Lab 1 — Local

```bash
cd labs/lab01
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python train.py
python serve.py
# http://localhost:8000/docs
```

### 3. Setup CI/CD

Xem `docs/MLOPS-LABS-CICD-GUIDE.md` Section 2:
- AWS OIDC role cho GitHub Actions
- GitHub Secrets: `AWS_ROLE_ARN`
- GitHub Variables: `AWS_REGION`, `EKS_CLUSTER_NAME`, `S3_BUCKET`

## Lộ trình labs

| Lab | Mô tả | Thời gian |
|-----|-------|-----------|
| [Lab 1](labs/lab01/) | Train & serve model local | 3–5h |
| [Lab 2](labs/lab02/) | GPU & AI workload | 2–3h |
| [Lab 3](labs/lab03/) | MLOps pipeline (DVC, MLflow) | 2–3 tuần |
| [Lab 4](labs/lab04/) | Data & model validation | 1 tuần |
| [Lab 5](labs/lab05/) | KServe trên EKS | 2 tuần |
| [Lab 6](labs/lab06/) | Kubeflow Pipeline | 2 tuần |
| [Lab 7](labs/lab07/) | Cost optimization | 1 tuần |
| [Lab 8](labs/lab08/) | vLLM LLM serving | 2 tuần |
| [Lab 9](labs/lab09/) | RAG platform | 2 tuần |
| [Lab 10](labs/lab10/) | Fine-tuning MLOps | 2 tuần |

## CI/CD workflows

| Workflow | Lab | Trigger |
|----------|-----|---------|
| `ci-lab01.yml` | Lab 1 | PR + push main |
| `mlops-lab03.yml` | Lab 3+4 | PR + push main |
| `deploy-kserve.yml` | Lab 5 | push + manual |
| `deploy-vllm.yml` | Lab 8 | push + manual |
| `deploy-rag.yml` | Lab 9 | push + manual |
| `cost-guardrails.yml` | Lab 7 | push + cron daily |

## Yêu cầu môi trường

- Python 3.10+
- Docker, kubectl, minikube/kind
- AWS CLI (Lab 3+)
- Helm, Terraform (Lab 5+)
