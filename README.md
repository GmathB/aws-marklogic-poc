# AWS MarkLogic Infrastructure

This project deploys MarkLogic database infrastructure on AWS using Terraform with automated CI/CD via GitHub Actions.

## Architecture

- **VPC**: Custom VPC with public and private subnets across 2 availability zones
- **Compute**: EC2 instances (t3.medium) running MarkLogic in private subnets
- **Security**: Security groups, IAM roles, and VPC endpoints for secure access
- **Storage**: S3 for Terraform state and MarkLogic installer
- **Secrets**: AWS Secrets Manager for credential management
- **Access**: AWS Systems Manager (SSM) for secure instance access without bastion hosts

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.6.0
- AWS CLI configured
- Session Manager Plugin (for SSM access)
- GitHub account (for CI/CD)

## Project Structure

```
.
├── backend.tf              # S3 backend configuration with state locking
├── provider.tf             # AWS provider configuration
├── vpc.tf                  # VPC, subnets, route tables, internet gateway
├── vpc_endpoints.tf        # VPC endpoints for SSM, S3, Secrets Manager
├── security.tf             # Security groups and network ACLs
├── compute.tf              # EC2 instances, IAM roles, instance profiles
├── state_management.tf     # S3 state bucket and Secrets Manager
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── github_oidc.tf          # GitHub Actions OIDC provider and IAM role
├── install_marklogic_simple.sh  # MarkLogic installation script
└── .github/workflows/terraform.yml  # CI/CD pipeline
```

## Quick Start

### 1. Clone and Configure

```bash
git clone <your-repo-url>
cd aws-marklogic
```

Update `github_oidc.tf` line 38 with your GitHub repository:
```terraform
"token.actions.githubusercontent.com:sub" = "repo:YOUR_USERNAME/YOUR_REPO:*"
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 3. Access MarkLogic

Get instance ID:
```bash
terraform output instance_id
```

Connect via SSM:
```bash
aws ssm start-session --target <instance-id> --region ap-south-1
```

Port forward to access Admin Console:
```bash
aws ssm start-session --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters "portNumber=8001,localPortNumber=8001" \
  --region ap-south-1
```

Open browser: http://localhost:8001

## GitHub Actions CI/CD

### Setup

1. Create GitHub repository and push code
2. Deploy OIDC infrastructure: `terraform apply`
3. Get role ARN: `terraform output github_actions_role_arn`
4. Add GitHub secret:
   - Go to Settings → Secrets and variables → Actions
   - Add secret: `AWS_ROLE_ARN` = (role ARN from step 3)
5. Create environments:
   - `production` (with required reviewers)
   - `destroy` (with required reviewers)

### Workflow Triggers

- Push to `main` branch (with .tf or .sh changes)
- Pull requests to `main` (plan only)
- Manual workflow dispatch

### Pipeline Stages

1. **Validate**: Format check and validation
2. **Plan**: Generate and upload Terraform plan
3. **Apply**: Deploy infrastructure (requires approval)
4. **Destroy**: Tear down infrastructure (manual trigger only)

## Configuration

### MarkLogic Installation

The installation script (`install_marklogic_simple.sh`) automatically:
- Downloads MarkLogic RPM from S3 bucket
- Installs dependencies
- Configures and starts MarkLogic service

**S3 Bucket**: `s3://marklogic-installer-bucket-013596899729/MarkLogic-12.0.1-rhel.x86_64.rpm`

### First-Time Setup

After deployment, configure MarkLogic:
1. Port forward to 8001
2. Open http://localhost:8001
3. Set admin username and password
4. Complete initial configuration

## Security Features

- **No Public Access**: All instances in private subnets
- **OIDC Authentication**: GitHub Actions uses short-lived tokens (no stored credentials)
- **Encrypted Storage**: EBS volumes and S3 buckets encrypted
- **VPC Endpoints**: Private connectivity to AWS services
- **Security Groups**: Restrictive inbound/outbound rules
- **IAM Roles**: Least privilege access policies
- **Secrets Manager**: Secure credential storage

## Networking

- **VPC CIDR**: 10.0.0.0/16
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24
- **Private Subnets**: 10.0.11.0/24, 10.0.12.0/24
- **Availability Zones**: ap-south-1a, ap-south-1b

## Outputs

```bash
terraform output instance_id              # EC2 instance ID
terraform output private_ip               # Private IP address
terraform output ssm_port_forward_command # SSM port forwarding command
terraform output github_actions_role_arn  # GitHub Actions IAM role ARN
```

## Troubleshooting

### MarkLogic Installation Issues

Check installation logs:
```bash
aws ssm start-session --target <instance-id>
sudo cat /var/log/marklogic-install.log
```

### SSM Connection Issues

Verify instance is registered:
```bash
aws ssm describe-instance-information \
  --filters "Key=tag:Name,Values=marklogic-node-1" \
  --region ap-south-1
```

### GitHub Actions Failures

- Verify `AWS_ROLE_ARN` secret is set correctly
- Check OIDC provider exists in AWS IAM
- Ensure repository name in `github_oidc.tf` matches actual repo

## Cost Optimization

- EC2 instances: t3.medium (can be adjusted in `compute.tf`)
- S3 buckets: Standard storage with versioning
- VPC Endpoints: Interface endpoints incur hourly charges
- No NAT Gateway (cost savings, uses VPC endpoints instead)

## Maintenance

### Update MarkLogic Version

1. Upload new RPM to S3 bucket
2. Update `install_marklogic_simple.sh` with new filename
3. Commit and push changes
4. GitHub Actions will deploy updated configuration

### Rotate Credentials

Update Secrets Manager:
```bash
aws secretsmanager update-secret \
  --secret-id marklogic-admin-credentials \
  --secret-string '{"username":"admin","password":"NewPassword"}' \
  --region ap-south-1
```

### Destroy Infrastructure

Via Terraform:
```bash
terraform destroy
```

Via GitHub Actions:
1. Go to Actions tab
2. Run workflow manually
3. Approve in `destroy` environment

## Best Practices

- Always review Terraform plan before applying
- Use pull requests for infrastructure changes
- Keep Terraform state in S3 (already configured)
- Regularly update dependencies and AMIs
- Monitor CloudWatch logs for issues
- Backup MarkLogic data regularly

## Support

For issues or questions:
- Check logs: `/var/log/marklogic-install.log`
- Review CloudWatch logs
- Verify VPC endpoint connectivity
- Check security group rules

## License

This project is for internal use.

## Author

Gomathi Balasubramanian

