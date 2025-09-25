#!/bin/bash
set -e

echo "Running post-traffic hook - validating deployment success..."

# Wait for traffic to stabilize
sleep 30

# Validate the application is working correctly
ALB_DNS="bank-alb-743777199.eu-west-2.elb.amazonaws.com"

# Test health endpoint
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/health || echo "000")

if [ "$HEALTH_RESPONSE" -eq 200 ]; then
    echo "Health check passed - deployment successful"
    exit 0
else
    echo "Health check failed - deployment may have issues"
    exit 1
fi