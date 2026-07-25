variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "mlops"
}

variable "environment" {
  type    = string
  default = "labs"
}

variable "key_name" {
  type        = string
  description = "Existing EC2 key pair name"
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket for MLOps artifacts"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR allowed for SSH (use your public IP/32)"
}

variable "allowed_app_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed for HTTP/HTTPS app ports"
}

variable "control_instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "gpu_instance_type" {
  type    = string
  default = "g4dn.xlarge"
}

variable "enable_gpu_node" {
  type    = bool
  default = true
}

variable "use_spot_gpu" {
  type    = bool
  default = true
}

variable "control_root_volume_gb" {
  type    = number
  default = 80
}

variable "gpu_root_volume_gb" {
  type    = number
  default = 100
}
