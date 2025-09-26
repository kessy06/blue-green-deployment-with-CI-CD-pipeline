# scripts/before_allow_traffic.sh
#!/bin/bash
set -e

echo "Running pre-traffic hook - validating green environment..."

# Simple validation - just check if our application is running locally
if docker ps | grep -q bencenet-app; then
    echo "Application container is running - ready for traffic switch"
    
    # Test local health endpoint
    HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/health || echo "000")
    
    if [ "$HEALTH_RESPONSE" -eq 200 ]; then
        echo "Local health check passed - green environment is ready"
        exit 0
    else
        echo "Local health check failed - green environment not ready"
        exit 1
    fi
else
    echo "Application container is not running - aborting traffic switch"
    exit 1
fi

# ================================================