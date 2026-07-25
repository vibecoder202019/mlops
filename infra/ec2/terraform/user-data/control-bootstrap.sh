#!/bin/bash
set -euo pipefail
exec > /var/log/mlops-bootstrap.log 2>&1

S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
REPO_URL="${repo_url}"

echo "=== MLOps Control Node Bootstrap ==="
date

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget git jq unzip apt-transport-https ca-certificates \
  software-properties-common python3 python3-pip python3-venv

# Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu

# AWS CLI v2
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/aws/install

# kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' > /etc/apt/sources.list.d/kubernetes.list
apt-get update -y && apt-get install -y kubectl

# k3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Clone repo
sudo -u ubuntu git clone "$REPO_URL" /home/ubuntu/mlops || true

# Env file
cat > /home/ubuntu/.mlops-env <<EOF
export AWS_REGION=${AWS_REGION}
export S3_BUCKET=${S3_BUCKET}
export MLFLOW_TRACKING_URI=http://localhost:5000
EOF
chown ubuntu:ubuntu /home/ubuntu/.mlops-env
echo 'source ~/.mlops-env' >> /home/ubuntu/.bashrc

echo "=== Bootstrap complete ==="
date
