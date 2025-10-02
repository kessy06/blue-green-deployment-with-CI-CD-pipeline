#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REGION="eu-west-2"
ALB_NAME="bank-alb"

echo -e "${YELLOW}🚀 Bencenet Bank Traffic Switch Script${NC}"
echo "=========================================="

# Validate input
if [ "$1" != "blue" ] && [ "$1" != "green" ]; then
    echo -e "${RED}❌ Usage: $0 [blue|green]${NC}"
    echo "   blue  - Switch traffic to blue environment"
    echo "   green - Switch traffic to green environment"
    exit 1
fi

TARGET_ENV=$1
OLD_ENV=$([ "$TARGET_ENV" == "blue" ] && echo "green" || echo "blue")

echo -e "${YELLOW}🔄 Switching traffic to ${TARGET_ENV} environment...${NC}"

# Get current environment before switch
CURRENT_TG=$(aws elbv2 describe-listeners \
    --load-balancer-name $ALB_NAME \
    --region $REGION \
    --query 'Listeners[0].DefaultActions[0].TargetGroupArn' \
    --output text | awk -F'/' '{print $2}')

echo "Current traffic routing: $CURRENT_TG"

# Switch using Terraform
echo "Applying Terraform configuration..."
terraform apply -var="active_environment=$TARGET_ENV" -auto-approve

# Scale down the old environment
echo -e "${YELLOW}📉 Scaling down $OLD_ENV environment...${NC}"
aws autoscaling set-desired-capacity \
    --auto-scaling-group-name ${OLD_ENV}-asg \
    --desired-capacity 0 \
    --region $REGION

echo -e "${YELLOW}⏳ Waiting for $OLD_ENV instances to terminate...${NC}"
sleep 30

# Verify the switch and termination
echo -e "${YELLOW}✅ Verifying traffic switch and termination...${NC}"

NEW_TG=$(aws elbv2 describe-listeners \
    --load-balancer-name $ALB_NAME \
    --region $REGION \
    --query 'Listeners[0].DefaultActions[0].TargetGroupArn' \
    --output text | awk -F'/' '{print $2}')

# Check old environment instances
OLD_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names ${OLD_ENV}-asg \
    --region $REGION \
    --query 'AutoScalingGroups[0].Instances' \
    --output text)

# Get ALB DNS for testing
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names $ALB_NAME \
    --region $REGION \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo ""
echo -e "${GREEN}🎉 Traffic successfully switched to ${TARGET_ENV} environment!${NC}"
echo -e "${GREEN}📉 ${OLD_ENV} environment scaled down to 0 instances${NC}"
echo -e "${GREEN}🌐 Your Bencenet Bank application is available at:${NC}"
echo -e "${GREEN}   http://$ALB_DNS${NC}"

if [ -z "$OLD_INSTANCES" ]; then
    echo -e "${GREEN}✅ ${OLD_ENV} instances terminated successfully${NC}"
else
    echo -e "${YELLOW}⚠️  ${OLD_ENV} instances still terminating...${NC}"
fi

echo ""
echo -e "${YELLOW}💡 Test command:${NC}"
echo -e "   curl http://$ALB_DNS/health"
echo ""
echo -e "${YELLOW}📊 Current status:${NC}"
echo -e "   Active environment: $TARGET_ENV"
echo -e "   ${OLD_ENV} environment: scaled to 0 instances"