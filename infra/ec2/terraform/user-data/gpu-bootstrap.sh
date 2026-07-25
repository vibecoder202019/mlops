#!/bin/bash
set -euo pipefail
exec > /var/log/mlops-gpu-bootstrap.log 2>&1

S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
REPO_URL="${repo_url}"

echo "=== MLOps GPU Node Bootstrap ==="
date

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl wget git jq unzip python3 python3-pip python3-venv

# NVIDIA driver (g4dn instances)
apt-get install -y ubuntu-drivers-common
ubuntu-drivers install --gpgpu || apt-get install -y nvidia-driver-535

# Docker + NVIDIA runtime
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu

distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update -y
apt-get install -y nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# AWS CLI
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/aws/install

sudo -u ubuntu git clone "$REPO_URL" /home/ubuntu/mlops || true

cat > /home/ubuntu/.mlops-env <<EOF
export AWS_REGION=${AWS_REGION}
export S3_BUCKET=${S3_BUCKET}
EOF
chown ubuntu:ubuntu /home/ubuntu/.mlops-env
echo 'source ~/.mlops-env' >> /home/ubuntu/.bashrc

echo "=== GPU Bootstrap complete — reboot may be required for nvidia-smi ==="
date
