resource "aws_security_group" "marklogic_sg" {
  name        = "marklogic-sg"
  description = "Security group for MarkLogic cluster"
  vpc_id      = aws_vpc.marklogic_vpc.id

  ingress {
    description = "MarkLogic Admin"
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "MarkLogic App Server"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Cluster communication"
    from_port   = 7997
    to_port     = 7997
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow all outbound via NAT gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "marklogic-security-group"
  }
}

# Inter-node rule removed - single node deployment, re-add when cluster is needed

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/marklogic-flowlogs"
  retention_in_days = 7
}

resource "aws_iam_role" "flow_logs_role" {
  name = "flowlogs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_logs_policy" {
  name = "flowlogs-policy"
  role = aws_iam_role.flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc_flow_logs" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.marklogic_vpc.id
  iam_role_arn         = aws_iam_role.flow_logs_role.arn
}

