# Lab 1 — Train & Serve Iris Classifier

Xem hướng dẫn chi tiết: [docs/MLOPS-AI-PLATFORM-LABS-GUIDE.md](../../docs/MLOPS-AI-PLATFORM-LABS-GUIDE.md#lab-1--train--serve-model-local)

## Quick start

```bash
cd labs/lab01
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python train.py
python serve.py
```

API: http://localhost:8000/docs

## Docker

```bash
python train.py
docker build -t iris-classifier:1.0.0 .
docker run -d -p 8000:8000 iris-classifier:1.0.0
```

## Kubernetes (Docker Desktop — macOS, khuyến nghị)

```bash
# Bật K8s: Docker Desktop → Settings → Kubernetes → Enable
bash ../../infra/macos/scripts/deploy-lab01-k8s.sh
curl http://localhost:30080/health
```

Xem: [MACOS-DOCKER-DESKTOP-K8S-GUIDE.md](../../docs/MACOS-DOCKER-DESKTOP-K8S-GUIDE.md)

## Kubernetes (minikube)

```bash
eval $(minikube docker-env)
docker build -t iris-classifier:1.0.0 .
kubectl apply -f k8s/
curl $(minikube ip):30080/health
```

## Istio Service Mesh

Xem: [docs/ISTIO-INTEGRATION-GUIDE.md](../../docs/ISTIO-INTEGRATION-GUIDE.md)

```bash
# Cài Istio (minikube)
istioctl install --set profile=demo -y
kubectl apply -f k8s/namespace.yaml
kubectl apply -n mlops -f k8s/deployment.yaml -f k8s/service.yaml
kubectl apply -n mlops -f k8s/istio/

# /etc/hosts
echo "$(minikube ip) iris.lab.local" | sudo tee -a /etc/hosts

# Test qua Istio Gateway
../../scripts/test-istio-lab01.sh
```

Manifests Istio: `k8s/istio/` (Gateway, VirtualService, DestinationRule, Canary, mTLS)

## ArgoCD GitOps (Canary / Blue-Green)

```bash
kubectl apply -f gitops/argocd/applications/lab01-canary-staging.yaml
argocd app sync lab01-iris-canary-staging
kubectl argo rollouts status rollout/iris-classifier -n mlops --watch
```

Xem: [ARGOCD-CANARY-BLUEGREEN-GUIDE.md](../../docs/ARGOCD-CANARY-BLUEGREEN-GUIDE.md)

## CI/CD

| Workflow | Mục đích |
|----------|----------|
| `ci-lab01.yml` | Test + build image |
| `argocd-canary-deploy.yml` | GitOps canary deploy |
| `argocd-bluegreen-deploy.yml` | Blue/green (manual) |
| `argocd-promote.yml` | Promote rollout |
| `argocd-rollback.yml` | Rollback rollout |
