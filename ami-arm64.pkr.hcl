packer {
  required_version = ">= 1.7.0"
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type        = string
  description = "The AWS region in which to build the temporary AMI."
  default     = "us-west-2"
}

variable "source_cidr" {
  type        = string
  description = "Local public IP address in CIDR notation. Used for restricting access to the temporary AMI via Security Group."
}

variable "kms_key_id" {
  type        = string
  description = "ID, alias or ARN of the KMS key to use for AMI encryption."
  default     = "alias/azureagent-ami"
}

locals {
  ami_description = "Amazon Linux 2 Arm64 arm64 HVM gp2 + languagetool Service ${timestamp()}"
  ami_name        = "languagetool-service-build-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
}

source "amazon-ebs" "languagetool_service" {
  # AMI Configuration
  ami_name                = local.ami_name
  ami_description         = local.ami_description
  ami_users               = ["239376665780"]
  ami_virtualization_type = "hvm"
  #encrypt_boot            = true
  #kms_key_id              = var.kms_key_id
  tags = {
    Name        = "Languagetool Service"
    Environment = "infra"
    Terraform   = "false"
    Packer      = "true"
  }

  # Access Configuration
  region = var.region

  # Assume Role Configuration

  # Polling Configuration

  # Run Configuration
  instance_type = "t4g.micro"
  ebs_optimized = true
  source_ami_filter {
    filters = {
      name                = "al2023-ami-ecs-hvm-2023.*-kernel-6.1-arm64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  run_tags = {
    Name        = "Languagetool Service"
    Environment = "infra"
    Terraform   = "false"
    Packer      = "true"
  }

  temporary_security_group_source_cidrs = [var.source_cidr]

  temporary_iam_instance_profile_policy_document {
    Statement {
      Action = ["s3:GetObject"]
      Effect = "Allow"
      Resource = [
        "arn:aws:s3:::lopescgc.models/languagetool/ngrams-en-20150817.zip"
      ]
    }
    Version = "2012-10-17"
  }

  # Session Manager Connections

  # Block Devices Configuration
  # Shortcut for encrypt_boot & kms_key_id:
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    encrypted             = true
    kms_key_id            = var.kms_key_id
    delete_on_termination = true
    volume_size           = 30
  }

  # Communicator Configuration
  ssh_username = "ec2-user"
}

build {
  description = "Customize the Amazon Linux 2 AMI to build custom AMI for Languagetool Service."
  sources     = ["source.amazon-ebs.languagetool_service"]

  provisioner "shell" {
    script = "ami.sh"
  }

  provisioner "shell" {
    execute_command = "sudo -S sh '{{ .Path }}'"
    inline_shebang  = "/bin/sh -e -x"
    inline = [
      "echo '** Shredding sensitive data ...'",
      "export HISTORY=0",
      "shred -u /etc/ssh/*_key /etc/ssh/*_key.pub",
      "shred -u /root/.*history /home/ec2-user/.*history",
      "shred -u /root/.ssh/authorized_keys /home/ec2-user/.ssh/authorized_keys",
      "sync; sleep 1; sync",
    ]
  }
}

