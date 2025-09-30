#!/bin/bash

set -e

# Configuration
REGION="eu-west-2"
ALB_ARN="your-alb-arn"  # Replace with your ALB ARN
BLUE_TG_ARN="your-blue-tg-arn"  # Replace with your blue target group ARN
GREEN_TG_ARN="your-green-tg-arn"  # Replace with your green target group ARN

echo "Starting traffic switch..."

# Switch traffic to green
echo "Switching traffic to green environment..."
aws elbv2 modify-listener \
    --listener-arn $ALB_ARN \
    --default-action Type=forward,TargetGroupArn=$GREEN_TG_ARN \
    --region $REGION

echo "Traffic switched to green environment"

# For rollback to blue
# aws elbv2 modify-listener \
#     --listener-arn $ALB_ARN \
#     --default-action Type=forward,TargetGroupArn=$BLUE_TG_ARN \
#     --region $REGION