locals {
  tags = {
    Project = var.name
    Env     = "dev"
  }
}

# Discover latest base AMIs if not pinned
data "aws_ami" "rhel9" {
  count       = var.rhel_ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["309956199498"] # Red Hat
  filter {
    name   = "name"
    values = ["RHEL-9.*x86_64*HVM*"]
  }
}

data "aws_ami" "win2022" {
  count       = var.win_ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["801119661308"] # Microsoft
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

locals {
  ami_rhel = var.rhel_ami_id != "" ? var.rhel_ami_id : data.aws_ami.rhel9[0].id
  ami_win  = var.win_ami_id != "" ? var.win_ami_id : data.aws_ami.win2022[0].id
}

# Resolve VPC from first public subnet (for SGs)
data "aws_subnet" "public0" {
  id = var.public_subnet_ids[0]
}

data "aws_vpc" "vpc" {
  id = data.aws_subnet.public0.vpc_id
}

# IAM role/profile for SSM on all EC2 instances
data "aws_iam_policy_document" "ec2_ssm_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name               = "${var.name}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_ssm_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}

# --------------------------
# Security Groups
# --------------------------

# Bastion SG (public)
resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion-sg"
  description = "SSH from your IP; egress all"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_cidr_ingress]
    description = "SSH from your IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Role = "bastion" })
}

# Private nodes SG (internal only)
resource "aws_security_group" "private" {
  name        = "${var.name}-private-sg"
  description = "Intra-VPC mgmt traffic; egress all"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "SSH"
  }

  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "WinRM HTTP/HTTPS"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Role = "private" })
}

# --------------------------
# User data
# --------------------------
locals {
  user_data_rhel_bastion = <<-EOT
    #cloud-config
    packages:
      - jq
      - git
      - python3
      - python3-pip
      - tar
    runcmd:
      - [ sh, -lc, "dnf -y update" ]
      - [ sh, -lc, "systemctl enable --now amazon-ssm-agent || true" ]
  EOT

  user_data_rhel = <<-EOT
    #cloud-config
    packages:
      - python3
      - jq
    runcmd:
      - [ sh, -lc, "dnf -y update" ]
      - [ sh, -lc, "systemctl enable --now amazon-ssm-agent || true" ]
  EOT

  user_data_windows = <<-EOT
    <powershell>
    Set-ExecutionPolicy Bypass -Scope Process -Force
    winrm quickconfig -q
    winrm set winrm/config/service '@{AllowUnencrypted="false"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    </powershell>
  EOT
}

# --------------------------
# Instances
# --------------------------

# Bastion (public)
resource "aws_instance" "bastion" {
  count                       = var.instance_counts.bastion
  ami                         = local.ami_rhel
  instance_type               = var.rhel_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  associate_public_ip_address = true
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  user_data                   = local.user_data_rhel_bastion

  tags = merge(local.tags, { Name = "${var.name}-bastion-${count.index}" })
}

resource "aws_eip" "bastion" {
  count    = var.instance_counts.bastion
  instance = aws_instance.bastion[count.index].id
  domain   ="vpc"

  tags = merge(local.tags, { Name = "${var.name}-bastion-eip-${count.index}" })
}

# AAP Controller (private)
resource "aws_instance" "aap_ctrl" {
  count                  = var.instance_counts.aap_ctrl
  ami                    = local.ami_rhel
  instance_type          = var.rhel_instance_type
  subnet_id              = var.private_subnet_ids[0]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  vpc_security_group_ids = [aws_security_group.private.id]
  user_data              = local.user_data_rhel

  tags = merge(local.tags, { Name = "${var.name}-aap-controller-${count.index}", Role = "aap-controller" })
}

# Private Automation Hub (private)
resource "aws_instance" "aap_hub" {
  count                  = var.instance_counts.aap_hub
  ami                    = local.ami_rhel
  instance_type          = var.rhel_instance_type
  subnet_id              = var.private_subnet_ids[0]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  vpc_security_group_ids = [aws_security_group.private.id]
  user_data              = local.user_data_rhel

  tags = merge(local.tags, { Name = "${var.name}-aap-hub-${count.index}", Role = "aap-hub" })
}

# EDA (private, optional)
resource "aws_instance" "aap_eda" {
  count                  = var.instance_counts.aap_eda
  ami                    = local.ami_rhel
  instance_type          = var.rhel_instance_type
  subnet_id              = var.private_subnet_ids[0]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  vpc_security_group_ids = [aws_security_group.private.id]
  user_data              = local.user_data_rhel

  tags = merge(local.tags, { Name = "${var.name}-aap-eda-${count.index}", Role = "aap-eda" })
}

# RHEL targets (private)
resource "aws_instance" "rhel_target" {
  count                  = var.instance_counts.rhel_targets
  ami                    = local.ami_rhel
  instance_type          = var.rhel_instance_type
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  vpc_security_group_ids = [aws_security_group.private.id]
  user_data              = local.user_data_rhel

  tags = merge(local.tags, { Name = "${var.name}-rhel-target-${count.index}", Role = "rhel-target" })
}

# Windows targets (private)
resource "aws_instance" "win_target" {
  count                  = var.instance_counts.win_targets
  ami                    = local.ami_win
  instance_type          = var.win_instance_type
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  vpc_security_group_ids = [aws_security_group.private.id]
  user_data              = local.user_data_windows

  tags = merge(local.tags, { Name = "${var.name}-win-target-${count.index}", Role = "win-target" })
}

