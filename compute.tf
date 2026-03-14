resource "aws_iam_role" "marklogic_ec2_role" {
  name = "marklogic-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.marklogic_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.marklogic_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "secrets_manager_policy" {
  name = "marklogic-secrets-manager-policy"
  role = aws_iam_role.marklogic_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:ap-south-1:*:secret:marklogic-*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_marklogic_policy" {
  name = "marklogic-s3-policy"
  role = aws_iam_role.marklogic_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::marklogic-installer-bucket-013596899729",
          "arn:aws:s3:::marklogic-installer-bucket-013596899729/*",
          "arn:aws:s3:::*marklogic*",
          "arn:aws:s3:::*marklogic*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "marklogic_profile" {
  name = "marklogic-instance-profile"
  role = aws_iam_role.marklogic_ec2_role.name
}

# Use Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# MarkLogic Node 1 (AZ: ap-south-1a)
resource "aws_instance" "marklogic_node_1" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.medium"

  subnet_id = aws_subnet.private_subnet_1.id
  
  associate_public_ip_address = false

  vpc_security_group_ids = [
    aws_security_group.marklogic_sg.id
  ]

  iam_instance_profile = aws_iam_instance_profile.marklogic_profile.name

  user_data = file("${path.module}/install_marklogic_simple.sh")
  user_data_replace_on_change = true
  
  root_block_device {
    volume_size = 50
    encrypted   = true
  }

  tags = {
    Name = "marklogic-node-test-1"
  }
}

