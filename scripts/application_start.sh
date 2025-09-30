#!/bin/bash

set -e

echo "Starting application..."

REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
ENVIRONMENT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" "Name=key,Values=Environment" --region $REGION --query 'Tags[0].Value' --output text)

echo "Pulling Bencenet Bank app from ECR..."
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bencenet-bank-app:latest

echo "Starting Bencenet Bank app container..."
docker run -d --name bencenet-app --restart unless-stopped -p 80:80 -e ENVIRONMENT=$ENVIRONMENT $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bencenet-bank-app:latest

echo "Bencenet Bank application started successfully in $ENVIRONMENT environment."