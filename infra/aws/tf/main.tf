data "aws_vpc" "default" {
  default = true
}

# Pick a default subnet in the default VPC (deterministic).
data "aws_subnets" "default_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  subnet_id = sort(data.aws_subnets.default_vpc_subnets.ids)[0]
}

# Ubuntu 22.04 LTS AMI via SSM parameter (region-safe)
data "aws_ssm_parameter" "ubuntu_2204_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# Read public key from local filesystem
data "local_file" "ssh_pub" {
  filename = var.ssh_public_key_path
}

resource "aws_key_pair" "stackpilot" {
  key_name   = var.ssh_key_name
  public_key = trimspace(data.local_file.ssh_pub.content)

  tags = {
    Name = "stackpilot-key"
  }
}

resource "aws_security_group" "stackpilot" {
  name        = "stackpilot-sg"
  description = "allow SSH + API from operator IP only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from operator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "API from operator IP"
    from_port   = var.api_port
    to_port     = var.api_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    description = "Outbound allowed (apt, docker pulls, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "stackpilot-sg"
  }
}

resource "aws_instance" "stackpilot" {
  ami           = data.aws_ssm_parameter.ubuntu_2204_ami.value
  instance_type = var.instance_type

  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.stackpilot.id]
  key_name               = aws_key_pair.stackpilot.key_name

  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_gb
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/usr/bin/env bash
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive

    # Basic tooling
    apt-get update -y
    apt-get install -y ca-certificates curl jq gnupg lsb-release rsync

    # Docker official repo
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

    apt-get update -y

    # Docker engine + compose plugin
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    # Optional: allow ubuntu user to run docker without sudo
    usermod -aG docker ubuntu || true

    # Marker file for bootstrap completion
    echo "ok" > /opt/stackpilot_bootstrap_done.txt
  EOF

  tags = {
    Name = "stackpilot"
  }
}