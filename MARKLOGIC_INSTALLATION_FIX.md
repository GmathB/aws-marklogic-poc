# MarkLogic Installation Fix - README

## Problem Identified

The MarkLogic installation was failing in userdata due to:
1. **Download Authentication**: MarkLogic downloads require developer account authentication
2. **CloudFormation Dependency**: Previous setup relied on CloudFormation templates
3. **AMI Issues**: Marketplace AMI requires subscription and may have licensing constraints
4. **Network Timing**: Userdata script may execute before VPC endpoints are fully ready

## Solution Implemented

### 1. Isolated CloudFormation Files
- Moved `cloudformation_stack.tf` and `marklogic-cloudformation.yaml` to `cloudformation-backup/` folder
- Now using pure Terraform approach with `compute.tf`

### 2. Fixed Installation Script
Created `install_marklogic_improved.sh` with:
- Better error handling (non-fatal errors don't stop execution)
- S3 bucket support for manual RPM upload
- Graceful failure with clear instructions
- Amazon Linux 2023 compatibility
- Improved logging to `/var/log/marklogic-install.log`

### 3. Updated Compute Configuration
- Changed from Marketplace AMI to Amazon Linux 2023 base AMI
- Added userdata script execution
- Added S3 permissions for RPM download
- Maintained all security configurations (SSM, Secrets Manager, etc.)

## Installation Options

### Option A: S3 Bucket Method (RECOMMENDED)

This is the most reliable method for automated installation.

#### Step 1: Download MarkLogic RPM
```bash
# Visit https://developer.marklogic.com/products/marklogic-server
# Sign up for free developer account
# Download: MarkLogic-11.2.0.x86_64.rpm (or latest version)
```

#### Step 2: Create S3 Bucket and Upload
```bash
# Create bucket (use unique name)
aws s3 mb s3://your-company-marklogic-rpms --region ap-south-1

# Upload RPM
aws s3 cp MarkLogic-11.2.0.x86_64.rpm s3://your-company-marklogic-rpms/

# Verify upload
aws s3 ls s3://your-company-marklogic-rpms/
```

#### Step 3: Update Installation Script
Edit `install_marklogic_improved.sh` (lines 48-52):
```bash
# Uncomment and update with your S3 bucket name
S3_BUCKET="your-company-marklogic-rpms"
if aws s3 cp s3://${S3_BUCKET}/MarkLogic-11.2.0.x86_64.rpm "$MARKLOGIC_RPM" 2>&1; then
  echo "✓ Downloaded MarkLogic from S3"
  DOWNLOAD_SUCCESS=true
fi
```

#### Step 4: Deploy
```bash
terraform init
terraform plan
terraform apply
```

The instance will automatically download and install MarkLogic from your S3 bucket.

---

### Option B: Manual Installation After Deployment

If you prefer to install manually or troubleshoot:

#### Step 1: Deploy Infrastructure
```bash
terraform apply
```

#### Step 2: Get Instance ID
```bash
INSTANCE_ID=$(terraform output -raw instance_id)
echo $INSTANCE_ID
```

#### Step 3: Connect via SSM
```bash
aws ssm start-session --target $INSTANCE_ID --region ap-south-1
```

#### Step 4: Manual Installation
```bash
# Inside the instance
cd /tmp

# Option 1: Download from S3 (if you uploaded)
aws s3 cp s3://your-company-marklogic-rpms/MarkLogic-11.2.0.x86_64.rpm .

# Option 2: Use wget/curl (if you have direct URL)
# wget https://your-url/MarkLogic-11.2.0.x86_64.rpm

# Install
sudo yum install -y MarkLogic-11.2.0.x86_64.rpm

# Start service
sudo systemctl enable MarkLogic
sudo systemctl start MarkLogic

# Verify
sudo systemctl status MarkLogic
```

#### Step 5: Verify Installation
```bash
# Check if ports are listening
sudo netstat -tln | grep -E '8000|8001|7997'

# Check logs
sudo tail -f /var/opt/MarkLogic/Logs/ErrorLog.txt
```

---

### Option C: Use AWS Marketplace AMI (Alternative)

If you have AWS Marketplace subscription:

1. Subscribe to MarkLogic in AWS Marketplace
2. Update `compute.tf` to use Marketplace AMI:
```hcl
data "aws_ami" "marklogic_marketplace" {
  most_recent = true
  owners      = ["679593333241"]
  
  filter {
    name   = "name"
    values = ["*MarkLogic-11*"]
  }
}

resource "aws_instance" "marklogic_node_1" {
  ami = data.aws_ami.marklogic_marketplace.id
  # ... rest of configuration
  # Remove user_data line
}
```

---

## Verification Steps

After installation (any method):

### 1. Check Service Status
```bash
aws ssm start-session --target $(terraform output -raw instance_id)

# Inside instance:
sudo systemctl status MarkLogic
```

Expected output: `active (running)`

### 2. Port Forward to Admin Console
```bash
aws ssm start-session \
  --target $(terraform output -raw instance_id) \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8001"],"localPortNumber":["8001"]}'
```

### 3. Access Admin Console
Open browser: http://localhost:8001

You should see MarkLogic setup wizard.

### 4. Initial Setup
1. Set admin username and password
2. Accept license agreement
3. Configure cluster (single node for POC)
4. Initialize databases

---

## Troubleshooting

### Issue: Userdata script fails
**Check logs:**
```bash
aws ssm start-session --target INSTANCE_ID
sudo cat /var/log/marklogic-install.log
sudo cat /var/log/cloud-init-output.log
```

### Issue: MarkLogic service won't start
**Check dependencies:**
```bash
sudo yum install -y glibc glibc-common libstdc++
sudo systemctl restart MarkLogic
sudo journalctl -u MarkLogic -n 50
```

### Issue: Can't connect via SSM
**Verify:**
1. VPC endpoints are created (check AWS Console)
2. Security groups allow HTTPS (443) from VPC CIDR
3. IAM role has `AmazonSSMManagedInstanceCore` policy
4. Wait 5-10 minutes after instance launch

### Issue: Download from S3 fails
**Check:**
```bash
# Test S3 access from instance
aws s3 ls s3://your-bucket-name/

# Check IAM role permissions
aws sts get-caller-identity
```

---

## Cost Optimization

If MarkLogic installation is not urgent:

1. **Deploy infrastructure first** (without MarkLogic)
2. **Verify connectivity** (SSM, VPC endpoints)
3. **Install MarkLogic manually** when ready
4. **Create AMI** from configured instance for future use

This approach:
- Validates infrastructure separately
- Allows troubleshooting without re-deploying
- Creates reusable AMI for faster future deployments

---

## Files Modified

1. ✅ `compute.tf` - Updated to use Amazon Linux 2023 + userdata
2. ✅ `install_marklogic_improved.sh` - New script with better error handling
3. ✅ `cloudformation_stack.tf` - Moved to `cloudformation-backup/`
4. ✅ `marklogic-cloudformation.yaml` - Moved to `cloudformation-backup/`

## Files Unchanged

- `vpc.tf` - VPC, subnets, NAT gateway (working correctly)
- `vpc_endpoints.tf` - SSM, Secrets Manager endpoints (working correctly)
- `security.tf` - Security groups (working correctly)
- `variables.tf`, `outputs.tf`, `provider.tf` - No changes needed

---

## Next Steps

1. Choose installation method (A, B, or C)
2. If using Option A: Upload RPM to S3 and update script
3. Run `terraform apply`
4. Wait 5-10 minutes for instance initialization
5. Connect via SSM and verify installation
6. Access Admin Console and complete setup

---

## Support Resources

- MarkLogic Documentation: https://docs.marklogic.com/
- MarkLogic Developer Site: https://developer.marklogic.com/
- AWS SSM Documentation: https://docs.aws.amazon.com/systems-manager/
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/

---

## Production Considerations

Before moving to production:

1. ✅ Enable automated backups
2. ✅ Configure multi-AZ deployment
3. ✅ Add Application Load Balancer
4. ✅ Enable CloudWatch detailed monitoring
5. ✅ Configure log aggregation
6. ✅ Set up automated patching
7. ✅ Implement disaster recovery plan
8. ✅ Enable AWS Backup for EBS volumes
9. ✅ Configure MarkLogic clustering
10. ✅ Set up TLS/SSL certificates
