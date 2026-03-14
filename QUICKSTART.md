# MarkLogic Terraform - Quick Start Guide

## Prerequisites
- AWS Account with appropriate permissions
- AWS CLI configured: `aws configure`
- Terraform installed (v1.5+)
- Bash/PowerShell terminal

## Deploy in 5 Steps

### Step 1: Initialize Terraform
```bash
cd aws-marklogic
terraform init
```

### Step 2: Review the Plan
```bash
terraform plan
# Review resources to be created (~35+ resources)
```

### Step 3: Deploy Infrastructure
```bash
terraform apply
# Review and type 'yes' to confirm
# Wait 5-10 minutes for deployment
```

### Step 4: Get Connection Details
```bash
INSTANCE_ID=$(terraform output -raw instance_id)
PRIVATE_IP=$(terraform output -raw private_ip)
echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $PRIVATE_IP"
```

### Step 5: Connect and Verify MarkLogic

**Open Two Terminals:**

**Terminal 1 - SSM Session:**
```bash
aws ssm start-session --target $INSTANCE_ID
# Inside session:
sudo systemctl status MarkLogic
# Should show "active (running)"
```

**Terminal 2 - Port Forwarding:**
```bash
aws ssm start-session --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8001"],"localPortNumber":["8001"]}'
# Leave running
```

**Terminal 3 - Access Admin UI:**
```bash
# In browser, go to:
http://localhost:8001

# First-time setup:
# - Set admin password
# - Accept license
# - Configure hostname: use $PRIVATE_IP
```

---

## Architecture Summary
```
AWS VPC (10.0.0.0/16)
├── Public Subnet (10.0.3.0/24)
│   └── NAT Gateway + EIP
├── Private Subnet 1 (10.0.1.0/24)
│   └── EC2 (t3.medium, MarkLogic, no public IP)
└── Private Subnet 2 (10.0.2.0/24)
    └── Reserved for cluster expansion

Security:
✅ No SSH access (SSM Session Manager only)
✅ No public IP on EC2
✅ Encrypted state management (S3 + DynamoDB)
✅ VPC endpoints for private connectivity
✅ Secrets Manager for credentials
```

---

## Common Commands

### Connect to Instance
```bash
aws ssm start-session --target $INSTANCE_ID
```

### Check MarkLogic Logs
```bash
# From SSM session:
sudo tail -f /var/opt/MarkLogic/Logs/ErrorLog.txt
```

### Port Forward for Admin UI
```bash
aws ssm start-session --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8001"],"localPortNumber":["8001"]}'
```

### Port Forward for App Server
```bash
aws ssm start-session --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8000"],"localPortNumber":["8000"]}'
```

### Get AWS Secrets
```bash
aws secretsmanager get-secret-value \
  --secret-id marklogic-admin-credentials \
  --region ap-south-1
```

### Destroy Infrastructure
```bash
terraform destroy
# Type 'yes' to confirm
# ~3 minutes to destroy all resources
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| SSM session fails | EC2 needs 2-3 min post-launch. Check SG allows HTTPS (443). |
| Can't reach 8001 | Port forwarding terminal still active? Browser cache cleared? |
| MarkLogic not running | SSH to instance, run: `sudo /etc/init.d/MarkLogic restart` |
| Terraform plan fails | Check AWS credentials: `aws sts get-caller-identity` |

---

## Important Notes

### State Management
- State file stored locally (`terraform.tfstate`)
- **To migrate to S3+DynamoDB**: Follow [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)
- Always back up state files!

### Costs
- **Estimated**: ~$100/month for POC
- **NAT Gateway**: Most expensive (~$32/month data processing)
- **For production**: Consider reserved instances, S3/DynamoDB autoscaling

### Security
- Default Secrets Manager password must be changed after first MarkLogic login
- Restrict security group CIDR blocks from `10.0.0.0/16` to specific IPs for production

---

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Access MarkLogic Admin UI
3. ⬜ Create databases and forests
4. ⬜ Configure MarkLogic applications
5. ⬜ Add monitoring and backups

See [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for detailed post-deployment steps and production considerations.
