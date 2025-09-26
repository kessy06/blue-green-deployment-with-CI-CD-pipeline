# scripts/after_install.sh
#!/bin/bash
set -e
set -x

echo "Starting AfterInstall hook..."

# Get AWS region and account ID from instance metadata
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)

echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"

# Login to ECR with proper error handling
echo "Logging in to Amazon ECR..."
if aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com; then
    echo "✓ ECR login successful"
else
    echo "✗ ECR login failed, but continuing..."
    echo "Checking if docker is running..."
    systemctl status docker
    echo "Checking AWS credentials..."
    aws sts get-caller-identity --region $REGION
fi

echo "AfterInstall hook completed successfully."