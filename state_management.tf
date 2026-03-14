data "aws_caller_identity" "current" {}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "marklogic-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "marklogic-terraform-state"
  }
}

# Enable versioning on S3 bucket
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption on S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "terraform_state_pab" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Secrets Manager for MarkLogic Admin Credentials (placeholder)
resource "aws_secretsmanager_secret" "marklogic_admin" {
  name                    = "marklogic-admin-credentials"
  recovery_window_in_days = 0

  tags = {
    Name = "marklogic-admin-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "marklogic_admin" {
  secret_id = aws_secretsmanager_secret.marklogic_admin.id
  secret_string = jsonencode({
    username = "admin"
    password = "ChangeMe@123" # Change this after first login
  })
}
