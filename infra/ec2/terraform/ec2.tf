resource "aws_instance" "control" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.control_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.control.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size = var.control_root_volume_gb
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data/control-bootstrap.sh", {
    s3_bucket  = var.s3_bucket
    aws_region = var.aws_region
    repo_url   = "https://github.com/vibecoder202019/mlops.git"
  })

  user_data_replace_on_change = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-control"
    Role = "control"
  })
}

resource "aws_instance" "gpu" {
  count                  = var.enable_gpu_node ? 1 : 0
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.gpu_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.gpu[0].id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size = var.gpu_root_volume_gb
    volume_type = "gp3"
  }

  dynamic "instance_market_options" {
    for_each = var.use_spot_gpu ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price                      = "0.40"
        spot_instance_type             = "one-time"
        instance_interruption_behavior = "stop"
      }
    }
  }

  user_data = templatefile("${path.module}/user-data/gpu-bootstrap.sh", {
    s3_bucket  = var.s3_bucket
    aws_region = var.aws_region
    repo_url   = "https://github.com/vibecoder202019/mlops.git"
  })

  user_data_replace_on_change = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-gpu"
    Role = "gpu"
  })
}
