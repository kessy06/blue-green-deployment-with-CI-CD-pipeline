#!/bin/bash
set -e

echo "Running pre-traffic hook - validating green environment..."

# Validate green environment is ready
REGION="eu-west-2"
GREEN_TG_ARN=$(aws elbv2 describe-target-groups --names green-tg --region $REGION --query 'TargetGroups[0].TargetGroupArn' --output text)

# Check green target group health
HEALTHY_TARGETS=$(aws elbv2 describe-target-health --target-group-arn $GREEN_TG_ARN --region $REGION --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]' --output json | jq '. | length' 2>/dev/null || echo "0")

if [ "$HEALTHY_TARGETS" -gt 0 ]; then
    echo "Green environment is healthy - ready for traffic switch"
    exit 0
else
    echo "Green environment is not healthy - aborting traffic switch"
    exit 1
fi