#!/bin/bash

set -e

echo "Starting ValidateService hook..."
exec > >(tee /var/log/validate_service.log) 2>&1

# Wait for application to start
echo "Waiting 30 seconds for application to fully initialize..."
sleep 30

# Check if container is running
echo "Checking if bencenet-app container is running..."
if docker ps | grep -q bencenet-app; then
    echo "✓ Bencenet Bank container is running"
else
    echo "✗ Bencenet Bank container is not running"
    echo "All containers:"
    docker ps -a
    echo "Container logs:"
    docker logs bencenet-app || true
    exit 1
fi

# Test health endpoint with retries
echo "Testing health endpoint..."
for i in {1..5}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/health || echo "000")
    
    if [ "$response" -eq 200 ]; then
        echo "✓ Health check passed (HTTP 200)"
        
        # Additional validation - check environment in health response
        health_info=$(curl -s http://localhost:80/health || echo "{}")
        echo "Health response: $health_info"
        
        echo "✓ ValidateService hook completed successfully"
        exit 0
    else
        echo "Attempt $i: Health check failed (HTTP $response), retrying in 10 seconds..."
        sleep 10
    fi
done

echo "✗ Health check failed after 5 attempts (HTTP $response)"
echo "Testing root endpoint:"
curl -v http://localhost:80/ || true
echo "Container logs:"
docker logs bencenet-app || true
exit 1