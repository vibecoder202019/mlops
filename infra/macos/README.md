# macOS — Docker Desktop Kubernetes

Scripts triển khai MLOps labs trên Mac với Docker Desktop built-in K8s.

## Yêu cầu

- macOS 12+ (Intel hoặc Apple Silicon)
- Docker Desktop 4.x+ với **Kubernetes enabled**
- RAM ≥ 8GB allocated to Docker Desktop

## Quick start

```bash
# 1. Bật K8s trong Docker Desktop → Settings → Kubernetes

# 2. Setup
bash infra/macos/scripts/setup-docker-desktop.sh

# 3. Lab 1
bash infra/macos/scripts/deploy-lab01-k8s.sh
curl http://localhost:30080/health

# 4. Lab 1 + Istio
bash infra/macos/scripts/deploy-lab01-istio.sh
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

## Scripts

| Script | Mô tả |
|--------|-------|
| `setup-docker-desktop.sh` | Verify DD K8s, namespace, optional Istio |
| `deploy-lab01-k8s.sh` | Build + deploy Lab 1 |
| `deploy-lab01-istio.sh` | Lab 1 + Istio routing |
| `setup-argocd.sh` | Cài ArgoCD |
| `cleanup-labs.sh` | Xóa namespace mlops |

## Docs

[docs/MACOS-DOCKER-DESKTOP-K8S-GUIDE.md](../../docs/MACOS-DOCKER-DESKTOP-K8S-GUIDE.md)
