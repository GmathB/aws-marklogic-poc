# VPC Endpoint for CloudWatch Logs (required for CloudWatch agent - replaces NAT)
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.marklogic_vpc.id
  service_name        = "com.amazonaws.ap-south-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet_1.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "marklogic-cloudwatch-logs-endpoint"
  }
}

# VPC Endpoint for Systems Manager (SSM)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.marklogic_vpc.id
  service_name        = "com.amazonaws.ap-south-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet_1.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "marklogic-ssm-endpoint"
  }
}

# VPC Endpoint for EC2 Messages (required for SSM)
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.marklogic_vpc.id
  service_name        = "com.amazonaws.ap-south-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet_1.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "marklogic-ec2messages-endpoint"
  }
}

# VPC Endpoint for SSM Messages (required for SSM)
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.marklogic_vpc.id
  service_name        = "com.amazonaws.ap-south-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet_1.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "marklogic-ssmmessages-endpoint"
  }
}

# VPC Endpoint for Secrets Manager
resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = aws_vpc.marklogic_vpc.id
  service_name        = "com.amazonaws.ap-south-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_subnet_1.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "marklogic-secrets-manager-endpoint"
  }
}

# VPC Endpoint for S3 (Gateway type - no cost)
# Covers standard S3. ip_resolve=4 in dnf.conf ensures yum uses IPv4 S3 URLs.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.marklogic_vpc.id
  service_name      = "com.amazonaws.ap-south-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]

  tags = {
    Name = "marklogic-s3-endpoint"
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.marklogic_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Response traffic within VPC only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "vpc-endpoints-security-group"
  }
}
