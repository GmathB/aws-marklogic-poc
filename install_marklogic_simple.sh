#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/marklogic-install.log"
exec > >(sudo tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "MarkLogic Installation - $(date)"
echo "=========================================="

########################################
# 1. OS Dependencies
########################################
echo "[INFO] Installing dependencies..."
sudo yum update -y
sudo yum install -y glibc libstdc++ gdb wget net-tools curl jq aws-cli python3

########################################
# 2. Service User
########################################
if ! id -u marklogic &>/dev/null; then
  echo "[INFO] Creating marklogic user..."
  sudo useradd -r -m -s /sbin/nologin marklogic
fi

########################################
# 3. Disable EC2 host mode (non-marketplace AMI fix)
########################################
echo "[INFO] Configuring MarkLogic settings..."
echo "MARKLOGIC_EC2_HOST=0" | sudo tee /etc/marklogic.conf

########################################
# 4. Directory Preparation
########################################
echo "[INFO] Preparing directories..."
sudo mkdir -p /opt/MarkLogic /var/opt/MarkLogic/Logs
sudo chown -R marklogic:marklogic /var/opt/MarkLogic /opt/MarkLogic

########################################
# 5. Download Installer
########################################
echo "[INFO] Downloading MarkLogic from S3..."
cd /tmp
if aws s3 cp s3://marklogic-installer-bucket-013596899729/MarkLogic-12.0.1-rhel.x86_64.rpm ./marklogic.rpm; then
  echo "[SUCCESS] Download complete"
else
  echo "[ERROR] S3 download failed — manual install required"
  exit 1
fi

########################################
# 6. Install RPM
########################################
echo "[INFO] Installing MarkLogic RPM..."
sudo yum install -y /tmp/marklogic.rpm
rm -f /tmp/marklogic.rpm

########################################
# 7. Start & Enable Service
########################################
echo "[INFO] Starting MarkLogic service..."
sudo systemctl daemon-reload
sudo systemctl enable MarkLogic
sudo systemctl start MarkLogic

########################################
# 8. Wait for Service Readiness
########################################
echo "[INFO] Waiting for MarkLogic service..."
for i in {1..60}; do
  if sudo systemctl is-active --quiet MarkLogic; then
    echo "[SUCCESS] Service is running"
    break
  fi
  sleep 2
done

########################################
# 9. Wait for Admin API
########################################
echo "[INFO] Waiting for Admin API readiness..."
for i in {1..60}; do
  if curl -s http://localhost:8001/admin/v1/init > /dev/null 2>&1; then
    echo "[SUCCESS] Admin API is reachable"
    break
  fi
  sleep 5
done

########################################
# 10. Fetch Admin Credentials Securely
########################################
echo "[INFO] Fetching admin credentials from Secrets Manager..."
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id marklogic-admin-credentials \
  --region ap-south-1 \
  --query SecretString \
  --output text)

ML_USER=$(echo "$SECRET" | jq -r '.username')
ML_PASS=$(echo "$SECRET" | jq -r '.password')

########################################
# 11. Initialize MarkLogic Cluster
########################################
echo "[INFO] Initializing MarkLogic..."
curl -s -X POST http://localhost:8001/admin/v1/init \
  -H "Content-Type: application/json" \
  -d '{}'

sleep 10

########################################
# 12. Configure Admin User (Triggers Restart)
########################################
echo "[INFO] Setting admin credentials..."
curl -s -X POST http://localhost:8001/admin/v1/instance-admin \
  -H "Content-Type: application/json" \
  -d "{\"admin-username\": \"$ML_USER\", \"admin-password\": \"$ML_PASS\", \"realm\": \"public\"}"

########################################
# 13. Wait for Restart
########################################
echo "[INFO] Waiting for MarkLogic restart..."
sleep 40

########################################
# 14. Final Status Check
########################################
if systemctl is-active --quiet MarkLogic; then
  echo "[SUCCESS] MarkLogic fully initialized"
else
  echo "[WARNING] Service restarted but status unclear"
fi

echo "=========================================="
echo "INSTALLATION COMPLETE"
echo "Admin Console: http://localhost:8001"
echo "SSM Access: aws ssm start-session --target <instance-id>"
echo "Logs: $LOG_FILE"
echo "=========================================="