# Tích Hợp Backstage — AI / MLOps Platform

> **Mục tiêu:** Biến 10 labs MLOps thành **Internal Developer Platform (IDP)** qua Backstage — một cổng duy nhất để học, tạo, triển khai và vận hành ML services.

---

## Mục lục

1. [Tổng quan kiến trúc](#1-tổng-quan-kiến-trúc)
2. [Backstage là gì trong context MLOps](#2-backstage-là-gì-trong-context-mlops)
3. [Cấu trúc platform trong repo](#3-cấu-trúc-platform-trong-repo)
4. [Bước 1 — Cài Backstage](#bước-1--cài-backstage)
5. [Bước 2 — Đăng ký Software Catalog](#bước-2--đăng-ký-software-catalog)
6. [Bước 3 — TechDocs (tài liệu labs)](#bước-3--techdocs-tài-liệu-labs)
7. [Bước 4 — Software Templates (Scaffolder)](#bước-4--software-templates-scaffolder)
8. [Bước 5 — Plugins (K8s, CI/CD, MLflow)](#bước-5--plugins-k8s-cicd-mlflow)
9. [Bước 6 — Custom homepage AI Platform](#bước-6--custom-homepage-ai-platform)
10. [Bước 7 — RBAC & ownership](#bước-7--rbac--ownership)
11. [Luồng người dùng (User journeys)](#11-luồng-người-dùng-user-journeys)
12. [Triển khai production](#12-triển-khai-production)
13. [Checklist hoàn thành](#13-checklist-hoàn-thành)

---

## 1. Tổng quan kiến trúc

```
                         ┌─────────────────────────────────────┐
                         │         BACKSTAGE PORTAL             │
                         │  (Developer / MLOps Engineer UI)     │
                         └──────────────┬──────────────────────┘
                                        │
        ┌───────────────┬───────────────┼───────────────┬───────────────┐
        ▼               ▼               ▼               ▼               ▼
   ┌─────────┐    ┌───────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
   │ Catalog │    │ TechDocs  │   │ Scaffolder│  │ K8s Plugin│  │ GitHub   │
   │ (labs,  │    │ (lab      │   │ (tạo ML   │  │ (EKS      │  │ Actions  │
   │ models, │    │  guides)  │   │  service) │  │  workloads)│  │ (CI/CD)  │
   │ APIs)   │    │           │   │           │  │           │  │          │
   └────┬────┘    └───────────┘   └─────┬─────┘   └─────┬─────┘   └────┬─────┘
        │                               │               │              │
        └───────────────────────────────┴───────────────┴──────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
              GitHub Repo           AWS EKS            MLflow / Grafana
           vibecoder202019/mlops   (KServe,vLLM)      (monitoring)
                    │
                    ▼
              S3 (DVC artifacts)
```

### Vai trò từng thành phần Backstage

| Thành phần | Vai trò với labs |
|------------|------------------|
| **Software Catalog** | Đăng ký Lab 1–10 như Components; EKS/S3 như Resources |
| **TechDocs** | Render `docs/MLOPS-*.md` thành portal tài liệu |
| **Scaffolder** | Template "Tạo ML Service mới" scaffold từ Lab 1 pattern |
| **K8s Plugin** | Xem pods KServe, vLLM, RAG trên EKS |
| **GitHub Actions** | Hiển thị trạng thái CI/CD từng lab |
| **Custom links** | Shortcut tới MLflow UI, Grafana, Argo/KFP |

---

## 2. Backstage là gì trong context MLOps

Backstage **không thay thế** MLflow, KServe hay GitHub Actions. Nó là **lớp portal** gom:

- **Discover** — tìm model service, API, pipeline đang chạy
- **Create** — tạo repo ML mới qua template chuẩn
- **Document** — docs labs luôn cập nhật từ Git
- **Operate** — link tới K8s, logs, CI, monitoring

Đây chính là **AI Platform Engineer** mindset: xây "internal product" cho ML team.

---

## 3. Cấu trúc platform trong repo

Repo `mlops` đã có thư mục `platform/backstage/`:

```
mlops/
├── platform/
│   └── backstage/
│       ├── catalog/
│       │   ├── domain.yaml           # Domain: ai-platform
│       │   ├── system.yaml           # System: mlops-labs
│       │   ├── labs.yaml             # Components Lab 1-10
│       │   ├── resources.yaml        # EKS, S3, MLflow
│       │   └── apis.yaml             # API definitions
│       ├── templates/
│       │   ├── ml-classifier-service/   # Template Lab 1 pattern
│       │   ├── mlops-pipeline/           # Template Lab 3 pattern
│       │   └── llm-serving-service/      # Template Lab 8 pattern
│       ├── app-config.snippet.yaml   # Paste vào app-config.yaml
│       └── mkdocs.yml                # TechDocs config
├── docs/                             # Nguồn TechDocs
└── labs/
```

---

## Bước 1 — Cài Backstage

### 1.1 Tạo Backstage app (máy local hoặc repo riêng)

```bash
# Node 18+ / 20+
npx @backstage/create-app@latest

# Đặt tên: mlops-backstage
# Thư mục: ~/Documents/work/mlops-backstage
cd ~/Documents/work/mlops-backstage
yarn install
yarn dev
# → http://localhost:3000
```

**Khuyến nghị:** Tách repo Backstage (`mlops-backstage`) khỏi repo labs (`mlops`), nhưng catalog và templates **trỏ về repo mlops trên GitHub**.

### 1.2 Cấu hình `app-config.yaml` — Catalog locations

Mở `app-config.yaml`, thêm (hoặc copy từ `platform/backstage/app-config.snippet.yaml`):

```yaml
catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, API, Resource, Location, Domain, Group, User, Template]
  locations:
    # Catalog entities từ repo mlops
    - type: url
      target: https://github.com/vibecoder202019/mlops/blob/main/platform/backstage/catalog/domain.yaml
      rules:
        - allow: [Domain]
    - type: url
      target: https://github.com/vibecoder202019/mlops/blob/main/platform/backstage/catalog/system.yaml
      rules:
        - allow: [System]
    - type: url
      target: https://github.com/vibecoder202019/mlops/blob/main/platform/backstage/catalog/labs.yaml
      rules:
        - allow: [Component]
    - type: url
      target: https://github.com/vibecoder202019/mlops/blob/main/platform/backstage/catalog/resources.yaml
      rules:
        - allow: [Resource]
    - type: url
      target: https://github.com/vibecoder202019/mlops/blob/main/platform/backstage/catalog/apis.yaml
      rules:
        - allow: [API]

    # Scaffolder templates
    - type: url
      target: https://github.com/vibecoder202019/mlops/blob/main/platform/backstage/templates/ml-classifier-service/template.yaml
      rules:
        - allow: [Template]
    - type: url
      target: https://github.com/vibecoder202019/mlops/blob/main/platform/backstage/templates/mlops-pipeline/template.yaml
      rules:
        - allow: [Template]
    - type: url
      target: https://github.com/vibecoder202019/mlops/blob/main/platform/backstage/templates/llm-serving-service/template.yaml
      rules:
        - allow: [Template]

    # TechDocs
    - type: url
      target: https://github.com/vibecoder202019/mlops/blob/main/catalog-info.yaml
      rules:
        - allow: [Component]
```

> **Lưu ý:** Nếu repo private, cần GitHub integration token trong Backstage (`integrations.github`).

### 1.3 GitHub integration

```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}

backend:
  reading:
    allow:
      - host: github.com
      - host: raw.githubusercontent.com
```

---

## Bước 2 — Đăng ký Software Catalog

### 2.1 Hierarchy Catalog (Best practice)

```
Domain: ai-platform
  └── System: mlops-labs
        ├── Component: lab01-iris-classifier    (Lab 1)
        ├── Component: lab03-housing-pipeline   (Lab 3)
        ├── Component: lab05-kserve-platform    (Lab 5)
        ├── Component: lab08-vllm-server        (Lab 8)
        ├── Component: lab09-rag-platform       (Lab 9)
        ├── API: iris-predict-api
        ├── API: llm-completions-api
        └── Resource: eks-mlops-cluster
              Resource: s3-mlops-artifacts
              Resource: mlflow-tracking
```

### 2.2 Entity kinds

| Kind | Ví dụ | Mô tả |
|------|-------|-------|
| **Domain** | `ai-platform` | Phạm vi nghiệp vụ AI/ML |
| **System** | `mlops-labs` | Nhóm services trong platform |
| **Component** | `lab01-iris-classifier` | Một service/model có thể deploy |
| **API** | `iris-predict-api` | OpenAPI contract |
| **Resource** | `eks-mlops-cluster` | Hạ tầng phụ thuộc |
| **Template** | `ml-classifier-service` | Scaffolder template |

### 2.3 Xem catalog sau khi import

1. Mở Backstage → **Catalog**
2. Filter: `kind:component`, `system:mlops-labs`
3. Click vào `lab01-iris-classifier` → tab **Overview**, **Docs**, **Kubernetes**, **CI/CD**

File entities có sẵn tại `platform/backstage/catalog/*.yaml`.

---

## Bước 3 — TechDocs (tài liệu labs)

### 3.1 Cấu hình TechDocs publisher

Trong `app-config.yaml`:

```yaml
techdocs:
  builder: 'local'       # dev: local | prod: external
  generator:
    runIn: 'docker'      # cần Docker khi generate
  publisher:
    type: 'local'        # prod: awsS3 hoặc googleGcs
```

Production:

```yaml
techdocs:
  builder: 'external'
  publisher:
    type: 'awsS3'
    awsS3:
      bucketName: 'mlops-techdocs'
      region: 'ap-southeast-1'
```

### 3.2 `catalog-info.yaml` ở root repo mlops

File này gắn TechDocs với repo (đã có trong repo):

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: mlops-labs-docs
  title: MLOps Labs Documentation
  description: Tài liệu và labs MLOps / AI Platform
  annotations:
    backstage.io/techdocs-ref: dir:.
    github.com/project-slug: vibecoder202019/mlops
spec:
  type: documentation
  lifecycle: production
  owner: group:mlops-team
  system: mlops-labs
```

### 3.3 `mkdocs.yml` (TechDocs navigation)

File tại `platform/backstage/mkdocs.yml` — copy hoặc symlink tới root repo:

```bash
# Trong repo mlops root
cp platform/backstage/mkdocs.yml ./mkdocs.yml
```

TechDocs sẽ render:
- `docs/index.md` — trang chủ
- `docs/MLOPS-AI-PLATFORM-LABS-GUIDE.md`
- `docs/MLOPS-LABS-CICD-GUIDE.md`
- `docs/BACKSTAGE-INTEGRATION-GUIDE.md`

### 3.4 Generate TechDocs local

```bash
cd ~/Documents/work/mlops-backstage
yarn techdocs:generate --source /Users/welcome/Documents/work/mlops
yarn techdocs:publish --source /Users/welcome/Documents/work/mlops
```

---

## Bước 4 — Software Templates (Scaffolder)

### 4.1 Ba template chính

| Template | Dựa trên Lab | Tạo ra |
|----------|--------------|--------|
| `ml-classifier-service` | Lab 1 | FastAPI + train + Docker + K8s + CI |
| `mlops-pipeline` | Lab 3 | DVC + MLflow + GitHub Actions |
| `llm-serving-service` | Lab 8 | vLLM Helm + deploy workflow |

### 4.2 Luồng Scaffolder

```
User → Backstage "Create" → chọn template
  → điền: tên service, owner, model type
  → Backstage tạo repo mới trên GitHub
  → push skeleton code + catalog-info.yaml + CI workflow
  → auto-register vào Catalog
```

### 4.3 Cấu hình Scaffolder

`app-config.yaml`:

```yaml
scaffolder:
  defaultAuthor:
    name: MLOps Platform
    email: mlops@company.com
  defaultCommitMessage: 'Initial scaffold from MLOps Platform template'
```

Template files: `platform/backstage/templates/*/template.yaml`

### 4.4 Sau khi scaffold — tự động vào Catalog

Mỗi repo mới cần `catalog-info.yaml`:

```yaml
metadata:
  annotations:
    backstage.io/managed-by-location: url:https://github.com/vibecoder202019/new-repo/catalog-info.yaml
    github.com/project-slug: vibecoder202019/new-repo
spec:
  system: mlops-labs
  owner: group:mlops-team
```

Backstage Catalog sẽ discover entity mới sau vài phút (hoặc trigger refresh).

---

## Bước 5 — Plugins (K8s, CI/CD, MLflow)

### 5.1 Kubernetes Plugin

Cài:

```bash
cd packages/app
yarn add @backstage/plugin-kubernetes
```

`app-config.yaml`:

```yaml
kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        - name: mlops-lab-cluster
          url: https://YOUR_EKS_API_ENDPOINT
          authProvider: 'aws'
          caData: ${EKS_CA_DATA}
          authMetadata:
            kubernetes.io/aws-assume-role: arn:aws:iam::ACCOUNT:role/BackstageEKSReader
            kubernetes.io/aws-external-id: backstage
```

Entity annotation (đã có trong `labs.yaml`):

```yaml
metadata:
  annotations:
    backstage.io/kubernetes-id: iris-classifier
    backstage.io/kubernetes-namespace: staging
    backstage.io/kubernetes-label-selector: 'app=iris-classifier'
```

→ Tab **Kubernetes** trên trang Component hiển thị pods, deployments, logs.

### 5.2 GitHub Actions Plugin

```bash
yarn add @backstage/plugin-github-actions
```

Entity annotation:

```yaml
metadata:
  annotations:
    github.com/project-slug: vibecoder202019/mlops
    github.com/workflows: ci-lab01.yml
```

→ Tab **CI/CD** hiển thị workflow runs.

### 5.3 MLflow — Custom link (nhanh nhất)

Chưa có plugin MLflow chính thức. Dùng **sidebar item** hoặc **entity link**:

```yaml
metadata:
  links:
    - url: http://mlflow.staging.internal:5000
      title: MLflow Experiments
      icon: dashboard
    - url: http://grafana.staging.internal
      title: Grafana Dashboards
      icon: dashboard
    - url: https://github.com/vibecoder202019/mlops/actions
      title: GitHub Actions
      icon: github
```

### 5.4 Plugin nâng cao (optional)

| Plugin | Package | Dùng cho |
|--------|---------|----------|
| Argo CD | `@roadiehq/backstage-plugin-argo-cd` | GitOps deploy Lab 5+ |
| Argo Workflows | `@roadiehq/backstage-plugin-argo-workflows` | Lab 9 ingestion |
| Grafana | `@k-phoen/backstage-plugin-grafana` | Dashboard embed |
| Prometheus | custom | Alert overview |

---

## Bước 6 — Custom homepage AI Platform

Tạo trang Home tùy chỉnh với **Homepage Toolkit**:

`packages/app/src/components/home/HomePage.tsx`:

```tsx
import { HomePageCompanyLogo } from '@backstage/plugin-home';
import { HomePageToolkit, ToolKitEdgeMenuItem } from '@backstage/plugin-home';
import { Content, Page, InfoCard } from '@backstage/core-components';
import { Grid } from '@material-ui/core';

export const homePage = (
  <Page themeId="home">
    <Content>
      <Grid container spacing={3}>
        <Grid item md={6}>
          <InfoCard title="MLOps Platform">
            <p>Chào mừng đến AI Platform. Chọn lab hoặc tạo service mới.</p>
          </InfoCard>
        </Grid>
        <Grid item md={6}>
          <HomePageToolkit
            tools={[
              { url: '/create', label: 'Tạo ML Service', icon: <ToolKitEdgeMenuItem /> },
              { url: '/catalog?filters[kind]=component&filters[user]=owned', label: 'My Services', icon: <ToolKitEdgeMenuItem /> },
              { url: '/docs/default/component/mlops-labs-docs', label: 'Lab Guides', icon: <ToolKitEdgeMenuItem /> },
              { url: '/catalog?filters[kind]=component&filters[tag]=lab', label: 'All Labs', icon: <ToolKitEdgeMenuItem /> },
            ]}
          />
        </Grid>
      </Grid>
    </Content>
  </Page>
);
```

Sidebar bổ sung:

```tsx
// packages/app/src/components/Root/Root.tsx
<SidebarItem icon={CatalogIcon} to="catalog?filters[tag]=lab" text="MLOps Labs" />
<SidebarItem icon={CreateComponentIcon} to="create" text="Create ML Service" />
```

---

## Bước 7 — RBAC & ownership

### 7.1 Groups & Users

`platform/backstage/catalog/org.yaml`:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: mlops-team
  description: MLOps / AI Platform team
spec:
  type: team
  profile:
    displayName: MLOps Team
  children: []
  members: [your-github-username]
---
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: your-github-username
spec:
  profile:
    displayName: Your Name
    email: you@company.com
  memberOf: [mlops-team]
```

### 7.2 Ownership

Mỗi Component có `spec.owner: group:mlops-team` → hiển thị trong **My Group** và filter **Owned**.

---

## 11. Luồng người dùng (User journeys)

### Journey 1 — Học lab mới

```
Backstage Home → "Lab Guides" (TechDocs)
  → Lab 3 MLOps Pipeline
  → Link tới repo labs/lab03 + CI workflow status
```

### Journey 2 — Tạo ML service mới

```
Backstage Create → "ML Classifier Service"
  → name: fraud-detector
  → owner: mlops-team
  → GitHub repo created: fraud-detector
  → CI chạy tự động
  → Catalog hiển thị component mới
```

### Journey 3 — Deploy & monitor

```
Catalog → lab08-vllm-server
  → Tab Kubernetes: pods, CPU/GPU
  → Tab CI/CD: deploy-vllm.yml status
  → Link: Grafana LLM dashboard
  → Link: MLflow experiments
```

### Journey 4 — Promote model production

```
Catalog → lab03-housing-pipeline
  → CI/CD: mlops-lab03.yml (staging deploy OK)
  → Manual: promote-model.yml (workflow_dispatch)
  → Environment: production (reviewer approve)
```

---

## 12. Triển khai production

### 12.1 Backstage trên Kubernetes

```bash
# Helm chart official
helm repo add backstage https://backstage.github.io/charts
helm install backstage backstage/backstage -n backstage --create-namespace \
  -f platform/backstage/helm-values.yaml
```

### 12.2 Kiến trúc production

```
Route53 / ALB
    → Backstage (EKS namespace: backstage)
    → PostgreSQL (RDS) — Backstage catalog DB
    → S3 — TechDocs published sites
    → EKS API — K8s plugin read-only role
    → GitHub App — repo access + scaffolder
```

### 12.3 Auth (production bắt buộc)

```yaml
auth:
  environment: production
  providers:
    github:
      production:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityName
```

Hoặc OIDC (Okta, Azure AD) cho enterprise.

---

## 13. Checklist hoàn thành

### Phase 1 — Portal cơ bản (1–2 tuần)

- [ ] Backstage app chạy local (`yarn dev`)
- [ ] Import catalog entities từ repo mlops
- [ ] TechDocs render lab guides
- [ ] GitHub integration hoạt động

### Phase 2 — Create & Operate (2–3 tuần)

- [ ] Template `ml-classifier-service` scaffold repo mới
- [ ] K8s plugin kết nối EKS
- [ ] GitHub Actions plugin hiển thị CI
- [ ] Custom homepage + sidebar

### Phase 3 — Production platform (3–4 tuần)

- [ ] Backstage deploy lên EKS
- [ ] Auth (GitHub/OIDC)
- [ ] TechDocs publisher S3
- [ ] RBAC groups/users
- [ ] Template mlops-pipeline + llm-serving
- [ ] Links MLflow, Grafana

---

## Tóm tắt

| Câu hỏi | Trả lời |
|---------|---------|
| Backstage thay MLflow? | **Không** — Backstage link tới MLflow |
| Labs nằm ở đâu? | Repo `mlops` — Backstage catalog trỏ tới |
| Tạo service mới? | Scaffolder template từ Lab 1/3/8 pattern |
| Docs labs? | TechDocs render từ `docs/` |
| CI/CD? | GitHub Actions plugin + entity annotations |
| Deploy K8s? | K8s plugin + annotations trên Component |

**Bước tiếp theo ngay:** Push `platform/backstage/` lên repo → cài Backstage local → paste `app-config.snippet.yaml` → mở Catalog xem 10 labs.

---

*Xem thêm file entities: `platform/backstage/catalog/` và templates: `platform/backstage/templates/`*
