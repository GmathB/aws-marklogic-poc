#!/bin/bash
set -e
exec > >(sudo tee /var/log/marklogic-install.log) 2>&1

echo "=========================================="
echo "MarkLogic Installation - $(date)"
echo "=========================================="

# Install dependencies
sudo yum update -y
sudo yum install -y glibc libstdc++ gdb wget net-tools

# Create MarkLogic user
if ! id -u marklogic &>/dev/null; then
  sudo useradd -r -m -s /sbin/nologin marklogic
fi

# Create directories
sudo mkdir -p /opt/MarkLogic /var/opt/MarkLogic/Logs
sudo chown -R marklogic:marklogic /var/opt/MarkLogic /opt/MarkLogic

# Download from S3
echo "Downloading MarkLogic from S3..."
cd /tmp
if aws s3 cp s3://marklogic-installer-bucket-013596899729/MarkLogic-12.0.1-rhel.x86_64.rpm ./marklogic.rpm; then
  echo "✓ Downloaded successfully"
else
  echo "✗ Failed to download from S3"
  echo "Manual installation required via SSM"
  exit 0
fi

# Install
echo "Installing MarkLogic..."
sudo yum install -y /tmp/marklogic.rpm
rm -f /tmp/marklogic.rpm

# Start service
sudo systemctl daemon-reload
sudo systemctl enable MarkLogic
sudo systemctl start MarkLogic

# Wait for service
echo "Waiting for MarkLogic to start..."
for i in {1..60}; do
  if sudo systemctl is-active --quiet MarkLogic; then
    echo "✓ MarkLogic is running"
    break
  fi
  sleep 2
done

echo "=========================================="
echo "✓ Installation Complete"
echo "Admin Console: http://localhost:8001"
echo "Access via: aws ssm start-session --target <instance-id>"
echo "=========================================="
