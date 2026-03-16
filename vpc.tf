resource "aws_vpc" "marklogic_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "marklogic-vpc"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.marklogic_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "marklogic-private-1"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.marklogic_vpc.id

  # No default route - all traffic stays within VPC via endpoints
  # SSM: ssm/ssmmessages/ec2messages endpoints
  # S3 (yum + installer): S3 gateway endpoint
  # Secrets Manager: secretsmanager endpoint
  # CloudWatch: logs endpoint (see vpc_endpoints.tf)

  tags = {
    Name = "marklogic-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}


