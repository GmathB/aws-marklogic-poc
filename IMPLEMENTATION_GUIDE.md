# MarkLogic Terraform POC - Implementation Guide

## Overview
This document addresses key architectural decisions, implementation details, and post-deployment procedures.

---

## 1. TERRAFORM STATE MANAGEMENT

### S3 Backend Configuration
- **S3 Bucket**: `marklogic-terraform-state-<ACCOUNT_ID>` (automatic naming to avoid conflicts)
- **State Locking**: DynamoDB table `marklogic-terraform-lock`
- **Encryption**: AES256 on S3, enabled on DynamoDB
- **Versioning**: Enabled for state recovery
- **Access**: Restricted to VPC only via S3 VPC endpoint

### Setup Steps
```bash
# 1. First, comment out backend.tf to create state management resources locally
# 2. Run: terraform apply
# 3. Once S3 and DynamoDB are created, uncomment backend.tf
# 4. Run: terraform init (will migrate state to S3)
# 5. Verify: terraform state list
```

---

## 2. NAT GATEWAY DECISION - POC vs PRODUCTION

### Current Setup (POC)
✅ **What we included:**
- NAT Gateway with EIP (in public subnet)
- Private route table routing to NAT (0.0.0.0/0 → NAT)
- VPC Endpoints for Systems Manager, EC2Messages, SSM Messages, Secrets Manager, and S3

### Why NAT Gateway is ESSENTIAL (even for POC)
**For MarkLogic Marketplace AMI:**
- Requires outbound internet access for license validation
- Needs to download security patches
- May fetch updates and dependencies
- Marketplace AMI integration communicates with AWS services

**For Systems Manager:**
- EC2 Instance needs to reach AWS Systems Manager service
- VPC endpoints solve this without internet gateway
- But if using marketplace features, outbound still needed

### Recommendation: **KEEP NAT Gateway** for POC
If you want to remove it temporarily:
```hcl
# Comment out NAT Gateway resources in vpc.tf
# Change private route table to NOT route through NAT
# This will break: package updates, license validation, SSM
```

---

## 3. MARKLOGIC INSTALLATION EXPLANATION

### Does Marketplace AMI Auto-Install?
✅ **YES** - MarkLogic Marketplace AMI includes:
- Pre-installed MarkLogic binary
- Service configured to run on startup
- Ports already bound (8001, 8000, 7997)

❌ **What it DOES NOT include:**
- Admin user credentials setup (you must configure)
- License activation (you must provide)
- Database/Forest initialization
- Performance tuning

### Why No User Data Script Now?
- User data isn't efficient with pre-installed AMI
- Installation overhead is wasted on pre-installed software
- Configuration management via System Manager is cleaner
- Allows better idempotency and error handling

### Initial Configuration Required After Deploy
See "POST-DEPLOYMENT STEPS" section below.

---

## 4. SECRETS MANAGER CONFIGURATION

### What We Added
```hcl
# Secrets Manager secret for admin credentials
aws_secretsmanager_secret.marklogic_admin
aws_secretsmanager_secret_version.marklogic_admin
```

**Important:** Change the default password after first login!

### How to Retrieve in Application
```bash
# Via EC2 Instance (using IAM role + VPC endpoint)
aws secretsmanager get-secret-value \
  --secret-id marklogic-admin-credentials \
  --region ap-south-1 \
  --query SecretString --output text
```

### Accessing from Local Machine
```bash
aws secretsmanager get-secret-value \
  --secret-id marklogic-admin-credentials \
  --region ap-south-1
```

---

## 5. VPC ENDPOINTS - SECURE ARCHITECTURE

### Endpoints Configured
| Service | Type | Purpose |
|---------|------|---------|
| SSM | Interface | Systems Manager Session Manager |
| EC2Messages | Interface | Session Manager backend |
| SSMMessages | Interface | Session Manager communication |
| Secrets Manager | Interface | Credential retrieval |
| S3 | Gateway | State files, backups |

### Benefits
✅ Private instances don't need internet gateway
✅ No data leaves AWS backbone
✅ Encryption in transit via private connection
✅ No charges for VPC endpoint to S3 (gateway type)
✅ Interface endpoints = $7.20/month each (acceptable for POC)

---

## 6. REMOVED CONFIGURATIONS
✅ **PEM Key**: Removed - using SSM Session Manager instead
✅ **User Data Script**: Removed - AMI is pre-configured
✅ **Public IP**: Disabled on EC2 instance
✅ **SSH Security Group Rule**: Removed port 22

---

## 7. POST-DEPLOYMENT STEPS

### Step 1: Deploy Infrastructure
```bash
terraform plan
terraform apply
# Takes ~5-10 minutes
```

### Step 2: Get Instance Details
```bash
INSTANCE_ID=$(terraform output -raw instance_id)
PRIVATE_IP=$(terraform output -raw private_ip)
echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $PRIVATE_IP"
```

### Step 3: Connect via SSM Session Manager
```bash
aws ssm start-session --target $INSTANCE_ID

# Inside the session, run:
sudo systemctl status MarkLogic
ps aux | grep MarkLogic
netstat -tlnp | grep java
```

### Step 4: Check MarkLogic Installation
```bash
# Verify service is running
sudo /etc/init.d/MarkLogic status

# Check process
ps aux | grep MarkLogic

# View logs
tail -f /var/opt/MarkLogic/Logs/ErrorLog.txt
```

### Step 5: Access MarkLogic Admin UI via Port Forwarding

**Terminal 1 - Start Port Forwarding:**
```bash
aws ssm start-session --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8001"],"localPortNumber":["8001"]}'
```

**Terminal 2 - Access Browser:**
```
http://localhost:8001
```

### Step 6: Initial MarkLogic Setup
1. **Admin Console** loads at `http://localhost:8001`
2. **Set admin credentials**: 
   - Username: `admin` (default)
   - Password: Create a strong password (NOT the one in Secrets Manager default)
3. **Accept License**: 
   - Copy license key from AWS Marketplace agreement
4. **Configure HostName**: 
   - Use the private IP (for cluster-ready setup)
5. **Initialize System**: 
   - Follow on-screen prompts

### Step 7: Access MarkLogic App Server (Port 8000)

**Terminal 1 - Port Forwarding:**
```bash
aws ssm start-session --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8000"],"localPortNumber":["8000"]}'
```

**Terminal 2 - Access:**
```
http://localhost:8000
```

---

## 8. IDENTIFIED GAPS FOR POC (Future Enhancements)

### Critical for Production
- [ ] **Database**: Add RDS (MySQL/PostgreSQL) if needed
- [ ] **Backup Strategy**: S3 lifecycle policies, Daily MarkLogic backups
- [ ] **Monitoring**: CloudWatch alarms for CPU, Memory, Disk
- [ ] **Logging**: MarkLogic logs to CloudWatch Logs
- [ ] **WAF**: AWS WAF rules for MarkLogic Admin UI
- [ ] **Encryption**: TLS/SSL for MarkLogic communication
- [ ] **HA/DR**: Multi-AZ deployment with Auto Scaling
- [ ] **Load Balancer**: Network Load Balancer for multi-node cluster

### Important for POC
- [x] **State Management**: S3 + DynamoDB ✅
- [x] **Secrets Management**: Secrets Manager ✅
- [x] **VPC Endpoints**: Secure connectivity ✅
- [x] **SSM Session Manager**: No SSH keys ✅
- [x] **Private Subnet**: Isolated from internet ✅
- [x] **IAM Roles**: Least privilege access ✅
- [ ] **Security Group Rules**: Consider stricter ingress (no VPC-wide access to MarkLogic)
- [ ] **CloudWatch Agent**: Send MarkLogic metrics to CloudWatch
- [ ] **Tagging Strategy**: Cost allocation tags

### Nice-to-Have
- [ ] **VPC Flow Logs**: Network troubleshooting (already added)
- [ ] **Systems Manager Parameter Store**: Configuration management
- [ ] **EventBridge**: Automated actions on instance state changes
- [ ] **SNS**: Email notifications for alarms

---

## 9. SECURITY CONSIDERATIONS

### Current Implementation
✅ **Strong Security Posture:**
- No internet-facing resources
- No SSH/bastion required
- SSM Session Manager encrypted
- IAM role-based access control
- VPC endpoints prevent data exfiltration
- State file encrypted in S3
- Secrets Manager for credentials

### Recommendations
1. **Rotation**: Add Secrets Manager automatic rotation
2. **MFA**: Enable MFA on AWS console access
3. **Logs**: Enable S3 access logging for state bucket
4. **Audit**: Enable CloudTrail for API auditing
5. **Network**: Add security group rules with specific CIDR ranges instead of 10.0.0.0/16

---

## 10. COST ESTIMATION (POC - Monthly)

| Resource | Estimate |
|----------|----------|
| EC2 t3.medium | $30 |
| NAT Gateway | $32 (data processing) |
| VPC Endpoints (5 × $7.20) | $36 |
| S3 Storage (small) | $1 |
| DynamoDB (on-demand) | $1 |
| Secrets Manager | $0.40 |
| **Total** | **~$100/month** |

---

## 11. NEXT STEPS

### Immediate
1. Deploy infrastructure
2. Access MarkLogic Admin UI
3. Complete initial setup
4. Test SSM Session Manager access

### Short-term
1. Add RDS database if needed
2. Configure CloudWatch monitoring
3. Set up automated backups

### Long-term
1. Implement HA/DR
2. Add load balancer
3. Multi-node cluster setup
4. Performance tuning

---

## Configuration Files Reference

| File | Purpose |
|------|---------|
| [main.tf](main.tf) | Main resources (empty - organized by domain) |
| [compute.tf](compute.tf) | EC2, IAM roles, instance profile |
| [vpc.tf](vpc.tf) | VPC, subnets, route tables, NAT Gateway |
| [security.tf](security.tf) | Security groups, VPC Flow Logs |
| [vpc_endpoints.tf](vpc_endpoints.tf) | VPC endpoints for private connectivity |
| [state_management.tf](state_management.tf) | S3, DynamoDB, Secrets Manager |
| [provider.tf](provider.tf) | AWS provider configuration |
| [variables.tf](variables.tf) | Input variables |
| [outputs.tf](outputs.tf) | Output values |
| [backend.tf](backend.tf) | S3 backend configuration |

---

## Troubleshooting

### MarkLogic Not Running
```bash
aws ssm start-session --target $INSTANCE_ID
sudo /etc/init.d/MarkLogic restart
sudo tail -100 /var/opt/MarkLogic/Logs/ErrorLog.txt
```

### SSM Session Manager Not Working
```bash
# Check EC2 can reach SSM endpoints
aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID"
```

### Can't Connect to Admin UI
1. Verify SSM port forwarding is still active
2. Check MarkLogic service is running
3. Verify firewall allows localhost:8001
4. Check browser console for errors

---

## Support & Documentation

- [MarkLogic Admin Reference](https://docs.marklogic.com/guide/admin)
- [AWS SSM Documentation](https://docs.aws.amazon.com/systems-manager/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
