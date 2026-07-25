# Hướng Dẫn Triển Khai CI/CD Cho Tất Cả MLOps Labs

> **Đi kèm:** `MLOPS-AI-PLATFORM-LABS-GUIDE.md`  
> **Stack CI/CD:** GitHub Actions + AWS (ECR, EKS, S3) + DVC + MLflow  
> **Nguyên tắc:** Mỗi lab có pipeline phù hợp mức độ; không over-engineer Lab 1, nhưng Lab 3+ phải có full MLOps pipeline.

---

## Mục lục

1. [Kiến trúc CI/CD tổng thể](#1-kiến-trúc-cicd-tổng-thể)
2. [Setup một lần (AWS + GitHub)](#2-setup-một-lần-aws--github)
3. [Chiến lược repo & branch](#3-chiến-lược-repo--branch)
4. [Lab 1 — CI: test + build image](#lab-1--ci-test--build-image)
5. [Lab 2 — CI: benchmark script](#lab-2--ci-benchmark-script)
6. [Lab 3+4 — Full MLOps CI/CD pipeline](#lab-34--full-mlops-cicd-pipeline)
7. [Lab 5 — CD: deploy KServe qua GitOps](#lab-5--cd-deploy-kserve-qua-gitops)
8. [Lab 6 — CI: compile & upload KFP pipeline](#lab-6--ci-compile--upload-kfp-pipeline)
9. [Lab 7 — CI: cost guardrails](#lab-7--ci-cost-guardrails)
10. [Lab 8 — CD: deploy vLLM + smoke test](#lab-8--cd-deploy-vllm--smoke-test)
11. [Lab 9 — CD: deploy RAG stack (Helm)](#lab-9--cd-deploy-rag-stack-helm)
12. [Lab 10 — CI/CD: GPU training job trigger](#lab-10--cicd-gpu-training-job-trigger)
13. [Reusable workflows & templates](#13-reusable-workflows--templates)
14. [Secrets & security checklist](#14-secrets--security-checklist)
15. [Troubleshooting CI/CD](#15-troubleshooting-cicd)

---

## 1. Kiến trúc CI/CD tổng thể

### 1.1 Pipeline stages theo loại lab

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        GITHUB ACTIONS                                    │
├──────────┬──────────┬──────────┬──────────┬──────────┬──────────────────┤
│  Lint    │  Test    │  Train   │ Validate │  Build   │  Deploy          │
│  ruff    │  pytest  │  dvc repro│ GE/Evidently│ Docker │ EKS/KServe  │
│  hadolint│  api test│  MLflow  │ quality gate│ push ECR│ Helm/ArgoCD   │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
                 AWS S3          AWS ECR         AWS EKS
              (DVC data)      (images)     (staging/prod)
```

### 1.2 CI vs CD theo từng lab

| Lab | CI (mỗi PR) | CD (merge main) | Deploy target |
|-----|-------------|-----------------|---------------|
| Lab 1 | lint, pytest, docker build | push ECR (optional) | minikube manual |
| Lab 2 | pytest benchmark | — | local/Colab |
| Lab 3+4 | lint, test, dvc repro, validate, quality gate | build → ECR → EKS staging | EKS staging |
| Lab 5 | manifest validate, kubeconform | KServe deploy staging → prod (manual approval) | EKS + KServe |
| Lab 6 | compile KFP pipeline | upload pipeline to KFP | Kubeflow |
| Lab 7 | terraform validate, cost script | apply lifecycle policies | AWS |
| Lab 8 | docker build (no GPU in CI) | deploy vLLM + smoke test | EKS GPU node |
| Lab 9 | helm lint, template test | helm upgrade RAG stack | EKS |
| Lab 10 | lint training code | trigger GPU training Job | EKS GPU Job |

### 1.3 Ba repo portfolio + CI/CD mapping

| Repo GitHub | Labs gộp | Workflows chính |
|-------------|----------|-----------------|
| `mlops-lab-01-iris-classifier` | Lab 1 | `ci.yml` |
| `mlops-pipeline-housing` | Lab 3, 4 | `mlops.yml`, `promote.yml` |
| `mlops-platform-eks` | Lab 5, 6, 7, 8, 9, 10 | `deploy-kserve.yml`, `deploy-vllm.yml`, `deploy-rag.yml`, `kfp-upload.yml`, `train-trigger.yml` |

**Khuyến nghị:** Gộp Lab 5–10 vào 1 repo `mlops-platform-eks` với thư mục `labs/lab05/`, `labs/lab08/`... để tái sử dụng IAM role và reusable workflows.

---

## 2. Setup một lần (AWS + GitHub)

### 2.1 Tạo IAM user/role cho GitHub Actions (OIDC — khuyến nghị)

**Bước 1:** Tạo OIDC provider trên AWS (nếu chưa có):

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03fa15197ed8c1e8bb45fd49359
```

**Bước 2:** Tạo IAM policy `MLOpsCICDPolicy`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:CreateRepository",
        "ecr:DescribeRepositories"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::mlops-labs-YOUR-NAME",
        "arn:aws:s3:::mlops-labs-YOUR-NAME/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["eks:DescribeCluster"],
      "Resource": "arn:aws:eks:ap-southeast-1:ACCOUNT_ID:cluster/mlops-lab-cluster"
    }
  ]
}
```

**Bước 3:** Tạo IAM Role `GitHubActionsMLOpsRole` với trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USER/*:*"
        }
      }
    }
  ]
}
```

**Bước 4:** Gắn policy vào role; lưu `AWS_ROLE_ARN`.

### 2.2 EKS access cho GitHub Actions

```bash
# Map IAM role vào EKS aws-auth / access entry
eksctl create iamidentitymapping \
  --cluster mlops-lab-cluster \
  --region ap-southeast-1 \
  --arn arn:aws:iam::ACCOUNT_ID:role/GitHubActionsMLOpsRole \
  --group system:masters \
  --username github-actions

# Hoặc EKS Access Entry (EKS 1.23+)
aws eks create-access-entry \
  --cluster-name mlops-lab-cluster \
  --principal-arn arn:aws:iam::ACCOUNT_ID:role/GitHubActionsMLOpsRole

aws eks associate-access-policy \
  --cluster-name mlops-lab-cluster \
  --principal-arn arn:aws:iam::ACCOUNT_ID:role/GitHubActionsMLOpsRole \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

### 2.3 Tạo ECR repositories

```bash
for repo in iris-classifier housing-price-api vllm-server embedding-service rag-api finetune-trainer; do
  aws ecr create-repository --repository-name $repo --region ap-southeast-1 2>/dev/null || true
done
```

### 2.4 GitHub repository secrets & variables

**Secrets** (Settings → Secrets and variables → Actions):

| Secret | Giá trị | Dùng cho |
|--------|---------|----------|
| `AWS_ROLE_ARN` | `arn:aws:iam::ACCOUNT:role/GitHubActionsMLOpsRole` | Tất cả workflows (OIDC) |

**Variables** (không nhạy cảm):

| Variable | Ví dụ | Dùng cho |
|----------|-------|----------|
| `AWS_REGION` | `ap-southeast-1` | Tất cả |
| `AWS_ACCOUNT_ID` | `123456789012` | ECR URI |
| `EKS_CLUSTER_NAME` | `mlops-lab-cluster` | Deploy |
| `S3_BUCKET` | `mlops-labs-yourname` | DVC, MLflow |
| `MLFLOW_TRACKING_URI` | `http://mlflow.staging.svc:5000` | Training |

**Không dùng** `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` nếu đã setup OIDC.

### 2.5 GitHub Environments

Tạo 3 environments (Settings → Environments):

| Environment | Protection rules | Deploy target |
|-------------|----------------|---------------|
| `dev` | Không | namespace `dev` |
| `staging` | Không (hoặc 1 reviewer) | namespace `staging` |
| `production` | Required reviewers: 1 | namespace `production` |

Mỗi environment có thể override variables (ví dụ `KSERVE_NAMESPACE`).

### 2.6 Cấu trúc thư mục CI/CD chuẩn

```
your-repo/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # Lab 1
│   │   ├── mlops.yml           # Lab 3+4
│   │   ├── promote-model.yml   # Lab 3+4 manual
│   │   ├── deploy-kserve.yml   # Lab 5
│   │   ├── kfp-upload.yml      # Lab 6
│   │   ├── deploy-vllm.yml     # Lab 8
│   │   ├── deploy-rag.yml      # Lab 9
│   │   └── train-trigger.yml   # Lab 10
│   └── actions/
│       └── aws-kubectl/
│           └── action.yml      # Reusable composite action
├── helm/
├── k8s/
├── labs/
│   ├── lab01/
│   ├── lab03/
│   └── ...
└── scripts/
    ├── quality-gate.sh
    ├── smoke-test.sh
    └── cost-check.sh
```

---

## Lab 1 — CI: test + build image

**Mục tiêu CI/CD:** Mỗi PR chạy lint + pytest; merge main build Docker image (push ECR optional).

### Workflow: `.github/workflows/ci.yml`

```yaml
name: Lab 1 — Iris Classifier CI

on:
  push:
    branches: [main, develop]
    paths:
      - "labs/lab01/**"
      - ".github/workflows/ci.yml"
  pull_request:
    branches: [main]
    paths:
      - "labs/lab01/**"

env:
  APP_DIR: labs/lab01
  IMAGE_NAME: iris-classifier

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ${{ env.APP_DIR }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: pip
          cache-dependency-path: ${{ env.APP_DIR }}/requirements.txt

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Train model (required for tests)
        run: python train.py

      - name: Run tests
        run: pytest tests/ -v --tb=short

      - name: Lint (optional)
        run: pip install ruff && ruff check serve.py train.py

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    permissions:
      id-token: write
      contents: read
    defaults:
      run:
        working-directory: ${{ env.APP_DIR }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Train & prepare model artifact
        run: |
          pip install -r requirements.txt
          python train.py

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Login to Amazon ECR
        id: ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ steps.ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/${{ env.IMAGE_NAME }}:$IMAGE_TAG .
          docker build -t $ECR_REGISTRY/${{ env.IMAGE_NAME }}:latest .
          docker push $ECR_REGISTRY/${{ env.IMAGE_NAME }}:$IMAGE_TAG
          docker push $ECR_REGISTRY/${{ env.IMAGE_NAME }}:latest

  # Deploy to dev K8s (optional — nếu có EKS)
  deploy-dev:
    needs: build
    runs-on: ubuntu-latest
    environment: dev
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}

      - name: Deploy to dev namespace
        env:
          ECR_REGISTRY: ${{ vars.AWS_ACCOUNT_ID }}.dkr.ecr.${{ vars.AWS_REGION }}.amazonaws.com
          IMAGE_TAG: ${{ github.sha }}
        run: |
          kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
          sed -i "s|iris-classifier:1.0.0|$ECR_REGISTRY/iris-classifier:$IMAGE_TAG|g" labs/lab01/k8s/deployment.yaml
          kubectl apply -f labs/lab01/k8s/ -n dev
          kubectl rollout status deployment/iris-classifier -n dev --timeout=120s
```

### Lab 1 — CD thủ công (local minikube)

CI không bắt buộc deploy local. Sau khi CI pass:

```bash
eval $(minikube docker-env)
cd labs/lab01 && python train.py
docker build -t iris-classifier:1.0.0 .
kubectl apply -f k8s/
```

---

## Lab 2 — CI: benchmark script

Lab 2 chủ yếu local/Colab. CI chỉ validate code chạy được trên CPU.

### Workflow: `.github/workflows/lab02-benchmark.yml`

```yaml
name: Lab 2 — HF Pipeline CI

on:
  push:
    paths: ["labs/lab02/**"]
  pull_request:
    paths: ["labs/lab02/**"]

jobs:
  test-hf-pipeline:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: labs/lab02
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: pip

      - name: Install (CPU only — no GPU in CI)
        run: |
          pip install transformers torch --index-url https://download.pytorch.org/whl/cpu
          pip install sentencepiece pytest

      - name: Run sentiment pipeline
        run: python hf_sentiment.py

      - name: Run unit tests
        run: pytest tests/ -v || echo "Add tests/ if missing"
```

**Ghi chú:** Benchmark GPU (Colab) không chạy trong CI — ghi kết quả thủ công vào README.

---

## Lab 3+4 — Full MLOps CI/CD pipeline

**Đây là pipeline quan trọng nhất** — mô hình cho toàn bộ MLOps CI/CD.

### Flow

```
PR opened
  → lint + unit test
  → dvc pull (S3)
  → validate data (Great Expectations)
  → dvc repro (train)
  → quality gate (R2 >= threshold)
  → build Docker image (không push)

Merge to main
  → (all above)
  → push image to ECR
  → deploy to staging (EKS)
  → smoke test
  → (manual) promote to production
```

### Workflow: `.github/workflows/mlops.yml`

```yaml
name: Lab 3+4 — MLOps Pipeline

on:
  push:
    branches: [main]
    paths:
      - "labs/lab03/**"
      - ".github/workflows/mlops.yml"
  pull_request:
    branches: [main]
    paths:
      - "labs/lab03/**"

env:
  APP_DIR: labs/lab03
  ECR_REPOSITORY: housing-price-api
  MIN_R2_SCORE: "0.75"

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ${{ env.APP_DIR }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: pip
          cache-dependency-path: ${{ env.APP_DIR }}/requirements.txt

      - run: pip install -r requirements.txt ruff
      - run: ruff check src/ tests/
      - run: pytest tests/ -v

  train-and-validate:
    needs: lint-and-test
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    defaults:
      run:
        working-directory: ${{ env.APP_DIR }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Install dependencies
        run: pip install -r requirements.txt "dvc[s3]"

      - name: Pull data from DVC remote
        run: dvc pull --force

      - name: Validate data (Great Expectations)
        run: python src/validate_data.py

      - name: Run training pipeline
        run: dvc repro --force
        env:
          MLFLOW_TRACKING_URI: ${{ vars.MLFLOW_TRACKING_URI }}

      - name: Quality gate — block bad models
        run: |
          chmod +x ../../scripts/quality-gate.sh
          ../../scripts/quality-gate.sh metrics.json ${{ env.MIN_R2_SCORE }}

      - name: Upload metrics artifact
        uses: actions/upload-artifact@v4
        with:
          name: training-metrics
          path: ${{ env.APP_DIR }}/metrics.json

      - name: Generate drift report (Lab 4)
        run: |
          pip install evidently
          python src/drift_report.py
        continue-on-error: true

  build-image:
    needs: train-and-validate
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    permissions:
      id-token: write
      contents: read
    defaults:
      run:
        working-directory: ${{ env.APP_DIR }}
    outputs:
      image_uri: ${{ steps.build.outputs.image_uri }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - uses: aws-actions/amazon-ecr-login@v2
        id: ecr

      - name: Prepare model for Docker
        run: |
          pip install -r requirements.txt "dvc[s3]"
          dvc pull --force
          dvc repro --force

      - name: Build and push
        id: build
        env:
          REGISTRY: ${{ steps.ecr.outputs.registry }}
          TAG: ${{ github.sha }}
        run: |
          IMAGE=$REGISTRY/${{ env.ECR_REPOSITORY }}:$TAG
          docker build -t $IMAGE -t $REGISTRY/${{ env.ECR_REPOSITORY }}:latest .
          docker push $IMAGE
          docker push $REGISTRY/${{ env.ECR_REPOSITORY }}:latest
          echo "image_uri=$IMAGE" >> $GITHUB_OUTPUT

  deploy-staging:
    needs: build-image
    runs-on: ubuntu-latest
    environment: staging
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Setup kubectl
        run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}

      - name: Deploy to staging
        env:
          IMAGE: ${{ needs.build-image.outputs.image_uri }}
        run: |
          kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
          helm upgrade --install housing-api ./labs/lab03/helm/housing-api \
            --namespace staging \
            --set image.repository=${IMAGE%:*} \
            --set image.tag=${IMAGE##*:} \
            --wait --timeout 5m

      - name: Smoke test
        run: |
          chmod +x scripts/smoke-test.sh
          scripts/smoke-test.sh staging housing-api 8000 /health
```

### Script: `scripts/quality-gate.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

METRICS_FILE="${1:?Usage: quality-gate.sh metrics.json MIN_R2}"
MIN_R2="${2:?Usage: quality-gate.sh metrics.json MIN_R2}"

R2=$(python3 -c "import json; print(json.load(open('$METRICS_FILE'))['r2_score'])")

echo "Model R2 score: $R2"
echo "Minimum required: $MIN_R2"

python3 -c "
import sys
r2 = float('$R2')
min_r2 = float('$MIN_R2')
if r2 < min_r2:
    print(f'QUALITY GATE FAILED: R2 {r2} < {min_r2}')
    sys.exit(1)
print(f'QUALITY GATE PASSED: R2 {r2} >= {min_r2}')
"
```

### Script: `scripts/smoke-test.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:?namespace}"
APP_LABEL="${2:?app label}"
PORT="${3:-8000}"
PATH_HEALTH="${4:-/health}"

echo "Running smoke test against $APP_LABEL in $NAMESPACE..."

kubectl run smoke-test-$(date +%s) \
  --namespace="$NAMESPACE" \
  --image=curlimages/curl:latest \
  --restart=Never \
  --rm -i \
  --command -- \
  curl -sf "http://${APP_LABEL}:${PORT}${PATH_HEALTH}"

echo "Smoke test PASSED"
```

### Workflow promote model (manual): `.github/workflows/promote-model.yml`

```yaml
name: Promote Model to Production

on:
  workflow_dispatch:
    inputs:
      model_version:
        description: "MLflow model version number"
        required: true
        type: string
      run_id:
        description: "MLflow run ID"
        required: true
        type: string

jobs:
  promote:
    runs-on: ubuntu-latest
    environment: production
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - run: pip install mlflow boto3

      - name: Promote model in MLflow Registry
        env:
          MLFLOW_TRACKING_URI: ${{ vars.MLFLOW_TRACKING_URI }}
        run: |
          python scripts/promote_model.py \
            --model-name housing-price-regressor \
            --version ${{ inputs.model_version }} \
            --stage Production

      - name: Configure AWS & deploy production
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}

      - name: Deploy to production
        run: |
          helm upgrade --install housing-api ./labs/lab03/helm/housing-api \
            --namespace production \
            --set image.tag=${{ github.sha }} \
            --wait
```

### Script: `scripts/promote_model.py`

```python
#!/usr/bin/env python3
import argparse
from mlflow.tracking import MlflowClient


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model-name", required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--stage", default="Production")
    args = p.parse_args()

    client = MlflowClient()
    client.transition_model_version_stage(
        name=args.model_name,
        version=args.version,
        stage=args.stage,
        archive_existing_versions=True,
    )
    print(f"Promoted {args.model_name} v{args.version} → {args.stage}")


if __name__ == "__main__":
    main()
```

---

## Lab 5 — CD: deploy KServe qua GitOps

### Chiến lược

- **CI (PR):** validate YAML (kubeconform), helm lint
- **CD (merge main):** deploy InferenceService lên staging
- **CD (manual approval):** promote canary → production

### Workflow: `.github/workflows/deploy-kserve.yml`

```yaml
name: Lab 5 — Deploy KServe

on:
  push:
    branches: [main]
    paths:
      - "labs/lab05/**"
      - ".github/workflows/deploy-kserve.yml"
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment"
        required: true
        default: staging
        type: choice
        options: [staging, production]
      canary_percent:
        description: "Canary traffic percent (0-100)"
        required: false
        default: "0"
        type: string

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install kubeconform
        run: |
          curl -L https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz
          sudo mv kubeconform /usr/local/bin/

      - name: Validate manifests
        run: |
          kubeconform -summary labs/lab05/k8s/
          helm lint labs/lab05/helm/iris-kserve || true

  deploy:
    needs: validate
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'staging' }}
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}

      - name: Ensure KServe installed
        run: |
          kubectl get namespace kserve 2>/dev/null || kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.14.0/kserve.yaml
          kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.14.0/kserve-cluster-resources.yaml
          kubectl wait --for=condition=ready pod -l control-plane=kserve-controller-manager -n kserve --timeout=300s

      - name: Sync model to S3 (if retrained)
        run: |
          aws s3 sync labs/lab05/models/ s3://${{ vars.S3_BUCKET }}/models/iris/latest/ || true

      - name: Deploy InferenceService
        env:
          NAMESPACE: ${{ inputs.environment || 'staging' }}
          CANARY: ${{ inputs.canary_percent || '0' }}
          S3_URI: s3://${{ vars.S3_BUCKET }}/models/iris/latest
        run: |
          kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
          helm upgrade --install iris-kserve ./labs/lab05/helm/iris-kserve \
            --namespace $NAMESPACE \
            --set predictor.model.storageUri=$S3_URI \
            --set predictor.canaryTrafficPercent=$CANARY \
            --wait --timeout 10m

      - name: Wait for InferenceService Ready
        env:
          NAMESPACE: ${{ inputs.environment || 'staging' }}
        run: |
          kubectl wait --for=condition=Ready inferenceservice/iris-sklearn \
            -n $NAMESPACE --timeout=600s

      - name: Inference smoke test
        env:
          NAMESPACE: ${{ inputs.environment || 'staging' }}
        run: |
          # Port-forward và test (hoặc dùng in-cluster curl)
          kubectl run kserve-smoke-$(date +%s) -n $NAMESPACE \
            --image=curlimages/curl --restart=Never --rm -i \
            --command -- curl -sf http://iris-sklearn-predictor.$NAMESPACE.svc.cluster.local/v1/models/iris:predict \
            -H "Content-Type: application/json" \
            -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}' || echo "Adjust URL for your KServe setup"
```

### Canary promotion workflow (manual)

```yaml
# .github/workflows/kserve-canary.yml
name: KServe Canary Promotion

on:
  workflow_dispatch:
    inputs:
      canary_percent:
        type: choice
        options: ["10", "50", "100"]
        default: "10"
      environment:
        default: staging

jobs:
  canary:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}
      - run: |
          helm upgrade iris-kserve ./labs/lab05/helm/iris-kserve \
            --namespace ${{ inputs.environment }} \
            --reuse-values \
            --set predictor.canaryTrafficPercent=${{ inputs.canary_percent }}
```

---

## Lab 6 — CI: compile & upload KFP pipeline

Kubeflow Pipeline không deploy qua kubectl thông thường — CI compile YAML và upload lên KFP API.

### Workflow: `.github/workflows/kfp-upload.yml`

```yaml
name: Lab 6 — Upload KFP Pipeline

on:
  push:
    branches: [main]
    paths:
      - "labs/lab06/pipeline/**"
  workflow_dispatch:

jobs:
  compile-and-upload:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install KFP SDK
        run: pip install "kfp==2.9.0" pyyaml

      - name: Compile pipeline
        working-directory: labs/lab06
        run: python pipeline/housing_pipeline.py
        # Output: housing_pipeline.yaml

      - name: Configure AWS & kubeconfig
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}

      - name: Port-forward ML Pipeline API & upload
        working-directory: labs/lab06
        run: |
          kubectl port-forward -n kubeflow svc/ml-pipeline 8888:8888 &
          sleep 5

          python - <<'EOF'
          import kfp
          client = kfp.Client(host="http://localhost:8888")
          pipeline = client.upload_pipeline(
              pipeline_package_path="housing_pipeline.yaml",
              pipeline_name="housing-training-pipeline",
              description="Uploaded by GitHub Actions",
          )
          print(f"Pipeline ID: {pipeline.pipeline_id}")
          EOF

      - name: Upload compiled YAML as artifact
        uses: actions/upload-artifact@v4
        with:
          name: kfp-pipeline-yaml
          path: labs/lab06/housing_pipeline.yaml
```

### Trigger pipeline run (manual)

```yaml
# .github/workflows/kfp-run.yml
name: Trigger KFP Pipeline Run

on:
  workflow_dispatch:
    inputs:
      n_estimators:
        default: "100"
      min_r2:
        default: "0.75"

jobs:
  run-pipeline:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install "kfp==2.9.0"
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}
      - run: |
          kubectl port-forward -n kubeflow svc/ml-pipeline 8888:8888 &
          sleep 5
          python scripts/trigger_kfp_run.py \
            --n-estimators ${{ inputs.n_estimators }} \
            --min-r2 ${{ inputs.min_r2 }}
```

---

## Lab 7 — CI: cost guardrails

Lab 7 tập trung IaC và policy — CI validate Terraform + chạy cost check script.

### Workflow: `.github/workflows/cost-guardrails.yml`

```yaml
name: Lab 7 — Cost Guardrails

on:
  push:
    paths:
      - "labs/lab07/**"
      - "terraform/**"
  schedule:
    - cron: "0 1 * * *"   # Daily 08:00 ICT — check cost
  workflow_dispatch:

jobs:
  terraform-validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3

      - name: Terraform fmt & validate
        working-directory: labs/lab07/terraform
        run: |
          terraform fmt -check
          terraform init -backend=false
          terraform validate

  cost-check:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Check running GPU instances
        run: |
          chmod +x scripts/cost-check.sh
          scripts/cost-check.sh

      - name: Apply S3 lifecycle (on main only)
        if: github.ref == 'refs/heads/main'
        run: |
          aws s3api put-bucket-lifecycle-configuration \
            --bucket ${{ vars.S3_BUCKET }} \
            --lifecycle-configuration file://labs/lab07/s3-lifecycle.json

  shutdown-idle-gpu:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}
      - name: Scale GPU nodegroup to 0 if idle
        run: |
          # Nếu không có pod dùng GPU → scale nodegroup về 0
          GPU_PODS=$(kubectl get pods -A -o json | python3 -c "
          import json,sys
          pods=json.load(sys.stdin)['items']
          print(sum(1 for p in pods if any('nvidia.com/gpu' in str(c.get('resources',{}).get('limits',{})) for c in p.get('spec',{}).get('containers',[]))))
          ")
          echo "GPU pods running: $GPU_PODS"
          if [ "$GPU_PODS" -eq 0 ]; then
            echo "No GPU workloads — consider scaling down GPU nodegroup"
            # eksctl scale nodegroup --cluster=... --name=gpu-spot --nodes=0
          fi
```

### Script: `scripts/cost-check.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

MAX_BUDGET="${MAX_BUDGET:-50}"
REGION="${AWS_REGION:-ap-southeast-1}"

echo "=== Cost Guardrail Check ==="

# Check running expensive instances
RUNNING_GPU=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[?contains(InstanceType,`g4`) || contains(InstanceType,`g5`) || contains(InstanceType,`p3`)].InstanceId' \
  --output text)

if [ -n "$RUNNING_GPU" ]; then
  echo "WARNING: GPU instances running: $RUNNING_GPU"
  echo "Verify these are expected lab instances"
else
  echo "OK: No GPU instances running"
fi

# EKS node count
if command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null 2>&1; then
  NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
  echo "EKS nodes: $NODES"
fi

echo "Cost check complete. Set AWS Budget alert at \$${MAX_BUDGET}/month in Console."
```

---

## Lab 8 — CD: deploy vLLM + smoke test

GPU training/inference **không chạy trong GitHub Actions runner** (không có GPU). CI chỉ build image; CD deploy lên EKS GPU node.

### Workflow: `.github/workflows/deploy-vllm.yml`

```yaml
name: Lab 8 — Deploy vLLM

on:
  push:
    branches: [main]
    paths:
      - "labs/lab08/**"
  workflow_dispatch:
    inputs:
      model_name:
        default: "meta-llama/Llama-3.2-1B-Instruct"
      environment:
        default: staging

env:
  ECR_REPOSITORY: vllm-server

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    outputs:
      image_uri: ${{ steps.push.outputs.image_uri }}
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - uses: aws-actions/amazon-ecr-login@v2
        id: ecr

      - name: Build vLLM image (upstream + config)
        id: push
        env:
          REGISTRY: ${{ steps.ecr.outputs.registry }}
          TAG: ${{ github.sha }}
        run: |
          # Option A: dùng upstream image, chỉ tag lại
          IMAGE=$REGISTRY/${{ env.ECR_REPOSITORY }}:$TAG
          docker pull vllm/vllm-openai:latest
          docker tag vllm/vllm-openai:latest $IMAGE
          docker push $IMAGE
          echo "image_uri=$IMAGE" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'staging' }}
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}

      - name: Ensure GPU nodegroup exists
        run: |
          eksctl get nodegroup --cluster ${{ vars.EKS_CLUSTER_NAME }} -n llm-gpu 2>/dev/null || \
          eksctl create nodegroup \
            --cluster ${{ vars.EKS_CLUSTER_NAME }} \
            --name llm-gpu \
            --node-type g5.xlarge \
            --nodes 1 --nodes-min 0 --nodes-max 1 \
            --spot \
            --node-taints nvidia.com/gpu=true:NoSchedule \
            --node-labels workload=gpu

      - name: Install NVIDIA device plugin
        run: |
          kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.5/nvidia-device-plugin.yml

      - name: Deploy vLLM
        env:
          NAMESPACE: ${{ inputs.environment || 'staging' }}
          MODEL: ${{ inputs.model_name || 'meta-llama/Llama-3.2-1B-Instruct' }}
          IMAGE: ${{ needs.build.outputs.image_uri }}
        run: |
          kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
          helm upgrade --install vllm ./labs/lab08/helm/vllm \
            --namespace $NAMESPACE \
            --set image.repository=${IMAGE%:*} \
            --set image.tag=${IMAGE##*:} \
            --set model.name=$MODEL \
            --set resources.gpu=1 \
            --wait --timeout 15m

      - name: LLM smoke test
        env:
          NAMESPACE: ${{ inputs.environment || 'staging' }}
        run: |
          chmod +x scripts/llm-smoke-test.sh
          scripts/llm-smoke-test.sh $NAMESPACE vllm 8000
```

### Script: `scripts/llm-smoke-test.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

NS="${1:?namespace}"
SVC="${2:?service}"
PORT="${3:-8000}"

echo "Waiting for vLLM pod to be ready..."
kubectl wait --for=condition=ready pod -l app=$SVC -n $NS --timeout=600s

kubectl run llm-smoke-$(date +%s) -n $NS \
  --image=curlimages/curl --restart=Never --rm -i \
  --command -- curl -sf "http://${SVC}:${PORT}/v1/models"

kubectl run llm-gen-$(date +%s) -n $NS \
  --image=curlimages/curl --restart=Never --rm -i \
  --command -- curl -sf "http://${SVC}:${PORT}/v1/completions" \
    -H "Content-Type: application/json" \
    -d '{"model":"meta-llama/Llama-3.2-1B-Instruct","prompt":"Hello","max_tokens":10}'

echo "LLM smoke test PASSED"
```

---

## Lab 9 — CD: deploy RAG stack (Helm)

Deploy multi-component: Qdrant + Embedding + vLLM + RAG API + Ingestion CronJob.

### Workflow: `.github/workflows/deploy-rag.yml`

```yaml
name: Lab 9 — Deploy RAG Platform

on:
  push:
    branches: [main]
    paths:
      - "labs/lab09/**"
  workflow_dispatch:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4
      - run: helm lint labs/lab09/helm/rag-platform

  build-images:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    strategy:
      matrix:
        service: [embedding-service, rag-api, ingestion]
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - uses: aws-actions/amazon-ecr-login@v2
        id: ecr
      - name: Build ${{ matrix.service }}
        env:
          REGISTRY: ${{ steps.ecr.outputs.registry }}
          TAG: ${{ github.sha }}
        run: |
          docker build -t $REGISTRY/${{ matrix.service }}:$TAG \
            -f labs/lab09/docker/${{ matrix.service }}.Dockerfile labs/lab09/
          docker push $REGISTRY/${{ matrix.service }}:$TAG

  deploy:
    needs: [lint, build-images]
    runs-on: ubuntu-latest
    environment: staging
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}

      - name: Deploy Qdrant
        run: |
          helm repo add qdrant https://qdrant.to/helm
          helm upgrade --install qdrant qdrant/qdrant \
            --namespace staging --create-namespace \
            -f labs/lab09/helm/qdrant-values.yaml

      - name: Deploy RAG platform
        env:
          REGISTRY: ${{ vars.AWS_ACCOUNT_ID }}.dkr.ecr.${{ vars.AWS_REGION }}.amazonaws.com
          TAG: ${{ github.sha }}
        run: |
          helm upgrade --install rag-platform ./labs/lab09/helm/rag-platform \
            --namespace staging \
            --set embedding.image.repository=$REGISTRY/embedding-service \
            --set ragApi.image.repository=$REGISTRY/rag-api \
            --set ingestion.image.repository=$REGISTRY/ingestion \
            --set image.tag=$TAG \
            --set vllm.enabled=true \
            --wait --timeout 15m

      - name: RAG end-to-end smoke test
        run: |
          kubectl wait --for=condition=ready pod -l app=rag-api -n staging --timeout=300s
          kubectl run rag-smoke-$(date +%s) -n staging \
            --image=curlimages/curl --restart=Never --rm -i \
            --command -- curl -sf http://rag-api:8080/health
```

### Ingestion pipeline CI (Argo Workflows)

```yaml
# .github/workflows/rag-ingest.yml
name: Trigger RAG Document Ingestion

on:
  workflow_dispatch:
  push:
    paths:
      - "labs/lab09/documents/**"

jobs:
  ingest:
    runs-on: ubuntu-latest
    environment: staging
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Sync documents to S3
        run: aws s3 sync labs/lab09/documents/ s3://${{ vars.S3_BUCKET }}/documents/

      - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}

      - name: Submit Argo Workflow
        run: |
          kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
          argo submit labs/lab09/workflows/ingest-documents.yaml -n staging --watch
```

---

## Lab 10 — CI/CD: GPU training job trigger

Fine-tuning cần GPU — CI lint code; CD trigger K8s Job trên GPU node.

### Workflow: `.github/workflows/train-trigger.yml`

```yaml
name: Lab 10 — Trigger LoRA Training

on:
  workflow_dispatch:
    inputs:
      dataset_size:
        description: "Number of training samples"
        default: "500"
      lora_r:
        default: "16"
      epochs:
        default: "1"
  push:
    branches: [main]
    paths:
      - "labs/lab10/src/**"

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install ruff
      - run: ruff check labs/lab10/src/

  build-trainer-image:
    needs: lint
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    outputs:
      image_uri: ${{ steps.out.outputs.image_uri }}
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - uses: aws-actions/amazon-ecr-login@v2
        id: ecr
      - id: out
        env:
          REGISTRY: ${{ steps.ecr.outputs.registry }}
          TAG: ${{ github.sha }}
        run: |
          IMAGE=$REGISTRY/finetune-trainer:$TAG
          docker build -t $IMAGE -f labs/lab10/Dockerfile labs/lab10/
          docker push $IMAGE
          echo "image_uri=$IMAGE" >> $GITHUB_OUTPUT

  launch-training-job:
    needs: build-trainer-image
    if: github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    environment: staging
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - run: aws eks update-kubeconfig --name ${{ vars.EKS_CLUSTER_NAME }}

      - name: Ensure GPU nodes
        run: |
          eksctl scale nodegroup --cluster ${{ vars.EKS_CLUSTER_NAME }} \
            --name llm-gpu --nodes 1 --nodes-min 1 2>/dev/null || true

      - name: Submit training Job
        env:
          IMAGE: ${{ needs.build-trainer-image.outputs.image_uri }}
          DATASET_SIZE: ${{ inputs.dataset_size }}
          LORA_R: ${{ inputs.lora_r }}
          EPOCHS: ${{ inputs.epochs }}
        run: |
          export IMAGE DATASET_SIZE LORA_R EPOCHS
          envsubst < labs/lab10/k8s/training-job.yaml | kubectl apply -n staging -f -
          JOB_NAME=$(kubectl get jobs -n staging --sort-by=.metadata.creationTimestamp -o name | tail -1)
          kubectl wait --for=condition=complete $JOB_NAME -n staging --timeout=3600s

      - name: Register model to MLflow (post-training)
        run: |
          kubectl logs -n staging -l job-name=lora-training --tail=100
          echo "Check MLflow UI for registered adapter"
```

### Template: `labs/lab10/k8s/training-job.yaml`

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: lora-training-${GITHUB_SHA::7}
spec:
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      nodeSelector:
        workload: gpu
      containers:
        - name: trainer
          image: ${IMAGE}
          command: ["python", "src/finetune_lora.py"]
          env:
            - name: DATASET_SIZE
              value: "${DATASET_SIZE}"
            - name: LORA_R
              value: "${LORA_R}"
            - name: NUM_EPOCHS
              value: "${EPOCHS}"
            - name: MLFLOW_TRACKING_URI
              value: "http://mlflow.staging.svc:5000"
          resources:
            limits:
              nvidia.com/gpu: 1
              memory: 32Gi
```

---

## 13. Reusable workflows & templates

### Composite action: `.github/actions/aws-kubectl/action.yml`

```yaml
name: AWS Kubectl Setup
description: Configure AWS OIDC and kubectl for EKS

inputs:
  role-arn:
    required: true
  region:
    required: true
  cluster-name:
    required: true

runs:
  using: composite
  steps:
    - uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ inputs.role-arn }}
        aws-region: ${{ inputs.region }}

    - shell: bash
      run: aws eks update-kubeconfig --name ${{ inputs.cluster-name }}
```

**Dùng trong workflow:**

```yaml
- uses: ./.github/actions/aws-kubectl
  with:
    role-arn: ${{ secrets.AWS_ROLE_ARN }}
    region: ${{ vars.AWS_REGION }}
    cluster-name: ${{ vars.EKS_CLUSTER_NAME }}
```

### Reusable workflow: docker-build-push

```yaml
# .github/workflows/reusable-docker-build.yml
name: Reusable Docker Build

on:
  workflow_call:
    inputs:
      app_dir:
        required: true
        type: string
      ecr_repository:
        required: true
        type: string
    outputs:
      image_uri:
        value: ${{ jobs.build.outputs.image_uri }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    outputs:
      image_uri: ${{ steps.push.outputs.image_uri }}
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - uses: aws-actions/amazon-ecr-login@v2
        id: ecr
      - id: push
        working-directory: ${{ inputs.app_dir }}
        env:
          REGISTRY: ${{ steps.ecr.outputs.registry }}
          TAG: ${{ github.sha }}
        run: |
          IMAGE=$REGISTRY/${{ inputs.ecr_repository }}:$TAG
          docker build -t $IMAGE .
          docker push $IMAGE
          echo "image_uri=$IMAGE" >> $GITHUB_OUTPUT
```

---

## 14. Secrets & security checklist

### Bắt buộc

- [ ] Dùng **OIDC** thay vì long-lived AWS access keys
- [ ] IAM policy **least privilege** (chỉ bucket/cluster cần thiết)
- [ ] GitHub Environment **production** có required reviewer
- [ ] Không commit `.env`, AWS keys, HuggingFace tokens
- [ ] ECR image scan enabled
- [ ] Quality gate block deploy khi metric fail

### Branch protection (Settings → Branches → main)

- [ ] Require pull request before merging
- [ ] Require status checks: `lint-and-test`, `train-and-validate`
- [ ] Require branches to be up to date

### MLOps-specific gates

| Gate | Stage | Action nếu fail |
|------|-------|-----------------|
| Unit test | CI | Block merge |
| Data validation (GE) | CI | Block merge |
| R2 >= threshold | CI | Block merge |
| Docker build | CD | Block deploy |
| Smoke test staging | CD | Rollback auto |
| Manual approval | Production | Human promote |

---

## 15. Troubleshooting CI/CD

| Lỗi | Nguyên nhân | Fix |
|-----|-------------|-----|
| `Could not assume role` | OIDC trust policy sai repo | Sửa `sub` condition khớp `repo:USER/REPO:*` |
| `dvc pull` 403 | IAM thiếu S3 permission | Thêm s3:GetObject cho bucket |
| `kubectl forbidden` | Role chưa map vào EKS | eksctl create iamidentitymapping |
| Quality gate fail trên PR | Data/model thay đổi | Kiểm tra metrics.json, adjust threshold tạm dev |
| vLLM deploy timeout | GPU node chưa ready | Check device plugin, node taint/toleration |
| KFP upload fail | Port-forward không stable | Dùng KFP host qua Ingress thay port-forward |
| ECR push denied | Repo chưa tạo | `aws ecr create-repository` |
| Helm `--wait` timeout | Image pull hoặc probe fail | `kubectl describe pod`, `kubectl logs` |

---

## Thứ tự triển khai CI/CD (khuyến nghị)

| Tuần | Việc làm |
|------|----------|
| 1 | Setup OIDC + ECR + GitHub vars/secrets |
| 2 | Lab 1 `ci.yml` — học pattern cơ bản |
| 3–4 | Lab 3+4 `mlops.yml` + quality gate + smoke test |
| 5 | Lab 5 `deploy-kserve.yml` + environments staging/prod |
| 6 | Lab 6 `kfp-upload.yml` |
| 7 | Lab 7 `cost-guardrails.yml` + scheduled job |
| 8–9 | Lab 8 `deploy-vllm.yml` + GPU nodegroup |
| 10 | Lab 9 `deploy-rag.yml` + ingest workflow |
| 11 | Lab 10 `train-trigger.yml` (manual dispatch) |

---

## Tóm tắt nhanh: workflow nào cho lab nào

| Lab | File workflow | Trigger | Deploy |
|-----|---------------|---------|--------|
| 1 | `ci.yml` | PR + push main | dev (optional) |
| 2 | `lab02-benchmark.yml` | PR | — |
| 3+4 | `mlops.yml` + `promote-model.yml` | PR + push + manual | staging → prod |
| 5 | `deploy-kserve.yml` + `kserve-canary.yml` | push + manual | staging/prod |
| 6 | `kfp-upload.yml` + `kfp-run.yml` | push + manual | Kubeflow |
| 7 | `cost-guardrails.yml` | push + cron daily | AWS policies |
| 8 | `deploy-vllm.yml` | push + manual | staging GPU |
| 9 | `deploy-rag.yml` + `rag-ingest.yml` | push + manual | staging |
| 10 | `train-trigger.yml` | manual | GPU Job |

---

*File này bổ sung cho `MLOPS-AI-PLATFORM-LABS-GUIDE.md`. Copy workflows vào repo thực tế, thay `YOUR-NAME`, `ACCOUNT_ID`, `YOUR_GITHUB_USER`.*
