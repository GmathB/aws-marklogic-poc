# Architectural Decisions & Gap Analysis

## Decision Log

### 1. NAT Gateway (DECIDED: KEEP)
**Question**: Do we need NAT Gateway for POC?

**Decision**: ✅ KEEP IT

**Reasoning**:
- MarkLogic Marketplace AMI requires (at minimum):
  - License validation calls to AWS
  - Security patch downloads
  - Marketplace integration communication
- VPC endpoints alone don't provide internet access
- SSM itself uses AWS APIs (covered by endpoints), but MarkLogic doesn't
- Costs: Only $32/month for small traffic
- Alternative (removing NAT) = breaking updates and licensing

**Implementation**:
```hcl
# NAT Gateway in public subnet (10.0.3.0/24)
# Private subnets route 0.0.0.0/0 → NAT → IGW
# Secure: No inbound internet access, only outbound
```

**Future Optimization**: For pure POC without real data, could remove if verified MarkLogic doesn't contact AWS.

---

### 2. S3 Backend with DynamoDB Lock (DECIDED: IMPLEMENT)
**Question**: How to manage Terraform state safely?

**Decision**: ✅ S3 + DynamoDB (with documentation for migration)

**Why Not Local State**:
- ❌ No collaboration/team access
- ❌ No state locking = concurrent apply conflicts
- ❌ No versioning = accidental deletions

**Implementation**:
- Account-ID-based naming to avoid conflicts
- Encryption at rest (AES256)
- Versioning enabled
- Public access blocked
- S3 Gateway endpoint (free tier)

**Setup**:
1. Run `terraform apply` (creates S3+DynamoDB locally)
2. Uncomment `backend.tf` with your Account ID
3. Run `terraform init` (migrates state)

---

### 3. Secrets Manager (DECIDED: IMPLEMENT)
**Question**: Where to store MarkLogic admin credentials?

**Decision**: ✅ AWS Secrets Manager

**Why Not**:
- ❌ Hardcoded in code = security risk
- ❌ CloudFormation parameters = exposed in console
- ❌ Parameter Store = less secure than Secrets Manager

**Implementation**:
```hcl
# Placeholder credentials (must be changed after login)
username: admin
password: ChangeMe@123

# Retrieved via IAM role + VPC endpoint
# EC2 instance can access without internet
```

**Rotation**: Currently manual. For production, enable automatic rotation.

---

### 4. VPC Endpoints (DECIDED: IMPLEMENT)
**Question**: How to keep EC2 completely private while maintaining AWS service access?

**Decision**: ✅ 5 VPC Endpoints

**Services**:
1. **SSM** - Session Manager connection
2. **EC2Messages** - Required by SSM
3. **SSMMessages** - Session Manager communication
4. **Secrets Manager** - Credential retrieval
5. **S3** (Gateway) - State files

**Benefits**:
- ✅ No internet gateway needed
- ✅ Data stays on AWS backbone
- ✅ Encrypted connections
- ✅ Private DNS resolution
- ❌ Cost: ~$36/month for interface endpoints (acceptable)

**Alternative**: Could remove in POC, but production must have these.

---

### 5. Removed PEM Key (DECIDED: REMOVE)
**Why**: You requested SSM Session Manager

**Implementation**:
- ❌ No `key_name` parameter on EC2
- ❌ No key pair resource
- ✅ SSM agent in IAM permissions
- ✅ Port 22 removed from security group

**Implications**:
- Can't SSH directly
- Must use `aws ssm start-session`
- More auditable (CloudTrail logs all sessions)
- More secure (no keys to manage)

---

### 6. MarkLogic Marketplace AMI (DECIDED: USE)
**Question**: Why not base Amazon Linux + install via user data?

**Decision**: ✅ Use Marketplace AMI

**Why**:
- ✅ Pre-optimized for MarkLogic
- ✅ Licensing built-in
- ✅ Performance tuning included
- ✅ Faster startup (no installation)
- ❌ Less control over version
- ❌ AWS Marketplace charges apply

**Removed User Data**:
- Installing on pre-installed system = waste
- Configuration via Systems Manager = cleaner
- Idempotent deployments = better

**Alternative**: Could use base AMI + user data for more control. Trade-off: slower, more complexity.

---

## POC Gaps Identified

### Security (High Priority)
- [ ] **VPC Flow Logs**: Implemented but not analyzed
- [ ] **CloudTrail**: No API logging
- [ ] **Security Group Auditing**: Rules allow /16 CIDR (should be /32 for production)
- [ ] **TLS/SSL**: MarkLogic ports not encrypted (HTTP, not HTTPS)
- [ ] **KMS Encryption**: S3/EBS using default AWS keys (not customer-managed)

### Availability (Medium Priority)
- [ ] **Multi-AZ**: Single instance in single AZ
- [ ] **Auto Scaling**: No auto-recovery on instance failure
- [ ] **Load Balancer**: No NLB for traffic distribution
- [ ] **Backup**: No automated MarkLogic backups

### Operations (Medium Priority)
- [ ] **CloudWatch Alarms**: No alerting on thresholds
- [ ] **CloudWatch Agent**: Not collecting metrics
- [ ] **Log Aggregation**: Logs not sent to CloudWatch
- [ ] **Cost Monitoring**: No budget alerts

### Management (Low Priority)
- [ ] **Tagging**: Basic tags only (no cost allocation)
- [ ] **Parameter Store**: No configuration management
- [ ] **Systems Manager Documents**: No runbooks
- [ ] **Terraform Modules**: Monolithic configuration

---

## Quick Fix for POC Gaps

### Add CloudWatch Monitoring (30 min)
```hcl
# Add to compute.tf
resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "marklogic-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### Enable Secrets Rotation (20 min)
```hcl
# Add to state_management.tf
resource "aws_secretsmanager_secret_rotation" "marklogic_admin" {
  secret_id           = aws_secretsmanager_secret.marklogic_admin.id
  rotation_rules {
    automatically_after_days = 30
  }
}
```

### Add RDS Database (if needed) (45 min)
```hcl
# Create database.tf
resource "aws_db_instance" "marklogic_database" {
  # PostgreSQL/MySQL for application data
  # Separate from MarkLogic databases
}
```

---

## Production Checklist

### Before Going Live
- [ ] Enable encryption at rest (KMS)
- [ ] TLS/SSL certificates for MarkLogic
- [ ] Multi-AZ deployment
- [ ] RDS backup retention (30 days)
- [ ] Daily MarkLogic backups to S3
- [ ] VPC peering/Transit Gateway setup
- [ ] Load balancer health checks
- [ ] CloudWatch alarms on critical metrics
- [ ] DLM lifecycle policies for snapshots
- [ ] Config as Code review + testing
- [ ] Disaster recovery plan document
- [ ] Security scanning (ECR, EBS, IAM)

### Monitoring
- [ ] CloudWatch dashboards
- [ ] Application performance monitoring
- [ ] Security monitoring (VPC Flow Logs)
- [ ] Cost tracking

### Compliance
- [ ] Encryption keys in customer account
- [ ] API logging (CloudTrail)
- [ ] Access logging (S3, ALB)
- [ ] Data retention policies
- [ ] Incident response plan

---

## Cost Optimization Recommendations

### Current POC (~$100/month)
| Resource | Monthly |
|----------|---------|
| EC2 t3.medium | $30 |
| NAT Gateway | $32 |
| VPC Endpoints | $36 |
| Storage/Other | $2 |

### Reduce for Proof-of-Concept
```hcl
# Option 1: Remove NAT Gateway (risky - breaks updates)
# Option 2: Use t3.small instead of .medium (-$10)
# Option 3: Serverless option (not applicable for MarkLogic)
```

### Reduce for Production
```hcl
# - Reserved instances (EC2 RI = 30-40% discount on t3.medium)
# - S3 Gateway endpoint (free vs $7.20/month interface)
# - DynamoDB on-demand (scales with usage)
# - Consolidate VPC endpoints (if multi-service)
```

---

## Why This Architecture is Good for POC

✅ **Secure**: No internet-facing components, private connectivity
✅ **Realistic**: Uses enterprise best practices (secrets, state locking, VPC endpoints)
✅ **Scalable**: Subnet structure ready for multi-node cluster
✅ **Auditable**: SSM session logging, CloudTrail integration
✅ **Production-Ready Foundation**: Easy to add HA/DR later
✅ **Low Complexity**: Understandable for team collaboration

---

## Next Phase Decisions (Production)

1. **Database**: Add RDS for application state
2. **Clustering**: Second EC2 for MarkLogic cluster node
3. **Load Balancer**: NLB for MarkLogic ports
4. **Disaster Recovery**: Cross-AZ backup + failover
5. **Monitoring**: Full observability stack
