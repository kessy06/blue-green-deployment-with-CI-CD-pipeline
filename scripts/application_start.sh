#!/bin/bash
set -e
echo "Starting application..."
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bencenet-bank-app:latest
docker run -d --name bencenet-app --restart unless-stopped -p 80:80 $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bencenet-bank-app:latest
echo "Application started successfully."