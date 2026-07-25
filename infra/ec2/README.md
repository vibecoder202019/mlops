# AWS EC2 Infrastructure for MLOps Labs

## Quick start

```bash
# 1. Copy và sửa config
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Sửa: s3_bucket, allowed_ssh_cidr (IP của bạn /32)

# 2. Deploy
cd terraform
terraform init && terraform apply

# 3. SSH
$(terraform output -ssh_control)

# 4. Deploy Lab 1
bash ~/mlops/infra/ec2/scripts/deploy-lab01-docker.sh
```

## Scripts

| Script | Mô tả |
|--------|-------|
| `setup-control-node.sh` | Istio + ArgoCD + Argo Rollouts trên k3s |
| `deploy-lab01-docker.sh` | Lab 1 Docker |
| `deploy-lab01-k3s.sh` | Lab 1 K3s + Istio |
| `deploy-lab08-vllm-docker.sh` | vLLM trên GPU EC2 |
| `deploy-lab09-rag-docker-compose.sh` | RAG stack docker-compose |
| `stop-all-lab-instances.sh` | Tắt EC2 tiết kiệm chi phí |
| `start-all-lab-instances.sh` | Bật lại EC2 |
| `health-check-all-labs.sh` | Kiểm tra services |

## Docs

[docs/AWS-EC2-LABS-DEPLOYMENT-GUIDE.md](../../docs/AWS-EC2-LABS-DEPLOYMENT-GUIDE.md)
