# GitOps — Lab 01 Blue/Green overlay

ArgoCD Application: `lab01-iris-bluegreen-staging`

## Deploy

```bash
kubectl apply -f gitops/argocd/applications/lab01-bluegreen-staging.yaml
argocd app sync lab01-iris-bluegreen-staging
```

## Test preview (green)

```bash
kubectl run test-preview -n mlops --image=curlimages/curl --rm -it --restart=Never -- \
  curl -sf http://iris-classifier-preview:8000/health
```

## Promote

```bash
kubectl argo rollouts promote rollout/iris-classifier-bg -n mlops
```

CI/CD: `.github/workflows/argocd-bluegreen-deploy.yml` (workflow_dispatch)
