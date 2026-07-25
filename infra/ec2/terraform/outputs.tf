output "control_public_ip" {
  description = "Public IP of control EC2 instance"
  value       = aws_instance.control.public_ip
}

output "control_private_ip" {
  value = aws_instance.control.private_ip
}

output "gpu_public_ip" {
  description = "Public IP of GPU EC2 instance"
  value       = var.enable_gpu_node ? aws_instance.gpu[0].public_ip : null
}

output "ssh_control" {
  description = "SSH command for control node"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.control.public_ip}"
}

output "ssh_gpu" {
  value = var.enable_gpu_node ? "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.gpu[0].public_ip}" : "GPU node disabled"
}

output "lab1_url_docker" {
  value = "http://${aws_instance.control.public_ip}:8000/docs"
}

output "s3_bucket" {
  value = var.s3_bucket
}

output "next_steps" {
  value = <<-EOT
    1. SSH: ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.control.public_ip}
    2. Wait ~5 min for bootstrap, then: tail -f /var/log/mlops-bootstrap.log
    3. cd mlops && bash infra/ec2/scripts/setup-control-node.sh
    4. Lab 1: bash infra/ec2/scripts/deploy-lab01-docker.sh
    5. Docs: docs/AWS-EC2-LABS-DEPLOYMENT-GUIDE.md
  EOT
}
