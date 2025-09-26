# scripts/after_allow_traffic.sh
#!/bin/bash
set -e

echo "Running post-traffic hook - validating deployment success..."

# Wait for traffic to stabilize
sleep 30

# Simple validation that the application is still running
if docker ps | grep -q bencenet-app; then
    echo "Application container is still running after traffic switch"
    
    # Test local application is still healthy
    HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/health || echo "000")
    
    if [ "$HEALTH_RESPONSE" -eq 200 ]; then
        echo "Post-deployment validation successful"
        exit 0
    else
        echo "Post-deployment health check failed"
        exit 1
    fi
else
    echo "Application container stopped running after traffic switch"
    exit 1
fi