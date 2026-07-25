# GitOps — Lab 01 Canary overlay

ArgoCD Application: `lab01-iris-canary-staging`

## Deploy

```bash
kubectl apply -f gitops/argocd/projects/mlops-project.yaml
kubectl apply -f gitops/argocd/applications/lab01-canary-staging.yaml
argocd app sync lab01-iris-canary-staging
```

## CI/CD

Workflow: `.github/workflows/argocd-canary-deploy.yml`

Flow: test → build ECR → update `kustomization.yaml` image tag → ArgoCD sync → canary 10→30→100%

## Manual

```bash
kubectl argo rollouts promote rollout/iris-classifier -n mlops
kubectl argo rollouts undo rollout/iris-classifier -n mlops
./scripts/test-argocd-canary.sh
```

Xem: [docs/ARGOCD-CANARY-BLUEGREEN-GUIDE.md](../../../docs/ARGOCD-CANARY-BLUEGREEN-GUIDE.md)
