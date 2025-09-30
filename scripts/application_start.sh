#!/bin/bash

set -e

echo "Starting ApplicationStart hook..."
exec > >(tee /var/log/application_start.log) 2>&1

REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
ENVIRONMENT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" "Name=key,Values=Environment" --region $REGION --query 'Tags[0].Value' --output text || echo "unknown")

echo "Pulling Bencenet Bank app from ECR..."
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bencenet-bank-app:latest

echo "Starting Bencenet Bank app container..."
docker run -d \
  --name bencenet-app \
  --restart unless-stopped \
  -p 80:80 \
  -e ENVIRONMENT=$ENVIRONMENT \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bencenet-bank-app:latest

# Wait for container to start
sleep 10

# Verify container is running
if docker ps | grep -q bencenet-app; then
    echo "Bencenet Bank container is running successfully"
    echo "Container status:"
    docker ps | grep bencenet-app
else
    echo "ERROR: Container failed to start"
    echo "All containers:"
    docker ps -a
    echo "Container logs:"
    docker logs bencenet-app || echo "No logs available"
    exit 1
fi

echo "ApplicationStart hook completed successfully."