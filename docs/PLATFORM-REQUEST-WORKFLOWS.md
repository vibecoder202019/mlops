# Platform Request Workflows — MLOps AI Platform

> Sơ đồ luồng request và workflow end-to-end cho toàn bộ platform.

---

## 1. Platform overview — ai mở rộng tới ai

```mermaid
flowchart TB
    subgraph Users
        DEV[MLOps Engineer]
        DS[Data Scientist]
        APP[Client Application]
    end

    subgraph DevPortal["Developer Portal"]
        BS[Backstage]
    end

    subgraph CICD["CI/CD Layer"]
        GH[GitHub]
        GHA[GitHub Actions]
    end

    subgraph Mesh["K8s + Istio Service Mesh"]
        IG[Istio Ingress Gateway]
        ML1[Lab 1 Iris API]
        ML3[Lab 3 Housing API]
        KS[Lab 5 KServe]
        VL[Lab 8 vLLM]
        RG[Lab 9 RAG API]
    end

    subgraph Data["Data & ML Ops"]
        DVC[DVC + S3]
        MLF[MLflow]
    end

    DEV --> BS
    BS --> GH
    GH --> GHA
    GHA -->|build deploy| Mesh
    GHA --> DVC
    GHA --> MLF
    DS --> MLF
    APP --> IG
    IG --> ML1
    IG --> ML3
    IG --> KS
    IG --> VL
    IG --> RG
    RG --> VL
    KS --> DVC
    ML3 --> DVC
```

---

## 2. Lab 1 — Online inference request

**Use case:** Client gửi features → nhận prediction.

```mermaid
sequenceDiagram
    autonumber
    box External
        participant C as Client
    end
    box Istio Mesh
        participant GW as Ingress Gateway
        participant VS as VirtualService
        participant SVC as Service iris-classifier
        participant POD as Pod v1 + Envoy
    end

    C->>GW: POST /predict<br/>Host: iris.lab.local<br/>Body: {sepal_length,...}
    GW->>VS: match route /predict
    VS->>SVC: forward (subset v1, weight 100%)
    SVC->>POD: traffic via sidecar :15001
    POD->>POD: FastAPI model.predict()
    POD-->>C: 200 {"prediction":"setosa",...}
```

**Không qua Istio (NodePort):**

```mermaid
flowchart LR
    C[curl] -->|NodePort 30080| SVC[Service]
    SVC --> P1[Pod :8000]
    SVC --> P2[Pod :8000]
```

---

## 3. Lab 3 — CI/CD train & deploy request flow

**Use case:** Push code → train → deploy staging.

```mermaid
sequenceDiagram
    participant DEV as Developer
    participant GH as GitHub
    participant CI as GitHub Actions
    participant S3 as S3 DVC
    participant MLF as MLflow
    participant EKS as EKS staging
    participant IG as Istio Gateway
    participant APP as housing-api Pod

    DEV->>GH: git push main
    GH->>CI: trigger mlops-lab03.yml
    CI->>S3: dvc pull data
    CI->>CI: train + validate + quality gate
    CI->>MLF: log metrics + register model
    CI->>EKS: helm upgrade staging
    EKS->>APP: rollout new image
    CI->>APP: smoke test /health (in-cluster)
    Note over DEV,APP: User test qua Istio
    DEV->>IG: GET /health Host: housing.lab.local
    IG->>APP: route traffic
    APP-->>DEV: 200 OK
```

---

## 4. Lab 5 — KServe model serving + canary

**Use case:** Inference với 2 model versions, split traffic 90/10.

```mermaid
flowchart TB
    C[Client] -->|POST /v1/models/iris:predict| IG[Istio Gateway]
    IG --> VS[VirtualService<br/>KServe managed]
    VS -->|90%| P1[Predictor v1]
    VS -->|10%| P2[Predictor v2]
    P1 --> S3[(Model artifact S3)]
    P2 --> S3
```

```mermaid
sequenceDiagram
    participant C as Client
    participant IG as Istio Gateway
    participant KS as KServe InferenceService
    participant M1 as Model v1
    participant M2 as Model v2

    C->>IG: inference request
    IG->>KS: route
    alt 90% traffic
        KS->>M1: predict
        M1-->>C: response v1
    else 10% traffic
        KS->>M2: predict
        M2-->>C: response v2
    end
```

---

## 5. Lab 8 — LLM chat completion request

**Use case:** OpenAI-compatible chat API qua vLLM.

```mermaid
sequenceDiagram
    participant C as OpenAI Client
    participant IG as Istio Gateway
    participant VS as VirtualService<br/>timeout 120s
    participant VL as vLLM Pod + GPU

    C->>IG: POST /v1/chat/completions<br/>Host: llm.lab.local
    IG->>VS: route
    VS->>VL: forward (no retry on stream)
    Note over VL: Token generation GPU
    VL-->>C: 200 stream tokens
```

**Headers quan trọng khi test:**

```
Host: llm.lab.local
Content-Type: application/json
Authorization: Bearer <token>   # nếu bật auth
```

---

## 6. Lab 9 — RAG query request (full chain)

**Use case:** User hỏi → retrieve context → LLM trả lời.

```mermaid
sequenceDiagram
    participant C as Client
    participant IG as Istio Gateway
    participant RAG as RAG API
    participant EMB as Embedding Service
    participant QD as Qdrant
    participant LLM as vLLM

    C->>IG: POST /query {"question":"..."}
    IG->>RAG: route rag.lab.local

    RAG->>EMB: POST /embed (mesh internal)
    EMB-->>RAG: vector[384]

    RAG->>QD: similarity search top-k
    QD-->>RAG: chunks[]

    RAG->>LLM: POST /v1/completions (context + question)
    LLM-->>RAG: answer text

    RAG-->>C: {"answer":"...","sources":[...]}
```

**Latency breakdown (typical):**

| Hop | Component | ~Latency |
|-----|-----------|----------|
| 1 | Gateway → RAG | 5–20ms |
| 2 | RAG → Embedding | 20–100ms |
| 3 | RAG → Qdrant | 10–50ms |
| 4 | RAG → vLLM | 500ms–5s |
| **Total** | | **0.5–6s** |

---

## 7. Canary deploy workflow (Istio)

**Use case:** Deploy model v2, test 10% traffic, promote 100%.

```mermaid
stateDiagram-v2
    [*] --> v1_100: Initial state
    v1_100 --> Canary_9010: Deploy v2 + apply VirtualService canary
    Canary_9010 --> Monitor: Watch error rate / latency Kiali
    Monitor --> v2_100: Metrics OK → weight v2=100
    Monitor --> Rollback_v1: Error spike → weight v1=100
    v2_100 --> [*]
    Rollback_v1 --> [*]
```

```mermaid
flowchart LR
    subgraph Traffic
        R100[100 requests]
    end
    R100 --> GW[Gateway]
    GW --> VS{VirtualService}
    VS -->|weight 90| V1[v1 pods x2]
    VS -->|weight 10| V2[v2 pod x1]
```

---

## 8. Backstage → Deploy → Test flow

```mermaid
sequenceDiagram
    participant U as User
    participant BS as Backstage
    participant SC as Scaffolder
    participant GH as GitHub
    participant CI as GitHub Actions
    participant EKS as EKS + Istio
    participant T as Test Script

    U->>BS: Create → ML Classifier Service
    BS->>SC: run template
    SC->>GH: new repo created
    GH->>CI: ci-lab01.yml
    CI->>EKS: deploy to mlops ns
    U->>T: ./scripts/test-istio-lab01.sh
    T->>EKS: health + predict via Gateway
    T-->>U: PASS / FAIL report
```

---

## 9. Request path summary table

| Lab | Entry point | Path | Backend port | Istio resources |
|-----|-------------|------|--------------|-----------------|
| Lab 1 | `iris.lab.local:80` | `/predict` | 8000 | Gateway, VS, DR |
| Lab 3 | `housing.lab.local:80` | `/health` | 8000 | Gateway, VS |
| Lab 5 | KServe host | `/v1/models/...:predict` | 8080 | KServe + Istio |
| Lab 8 | `llm.lab.local:80` | `/v1/chat/completions` | 8000 | Gateway, VS (long timeout) |
| Lab 9 | `rag.lab.local:80` | `/query` | 8080 | Gateway, VS + mesh internal |

---

## 10. Test commands nhanh (có Istio)

```bash
# Lab 1
export GW="http://$(minikube ip):$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name==\"http2\")].nodePort}')"
curl -H "Host: iris.lab.local" $GW/health
curl -H "Host: iris.lab.local" -H "Content-Type: application/json" \
  -X POST $GW/predict -d @labs/lab01/sample.json

# Automated
./scripts/test-istio-lab01.sh

# Kiali graph
istioctl dashboard kiali
```

Chi tiết Istio: [ISTIO-INTEGRATION-GUIDE.md](ISTIO-INTEGRATION-GUIDE.md)
