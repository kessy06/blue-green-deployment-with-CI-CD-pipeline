#!/bin/bash

set -e

echo "Starting ValidateService hook..."

# Wait for application to start
echo "Waiting 30 seconds for application to fully initialize..."
sleep 30

# Check if container is running
echo "Checking if bencenet-app container is running..."
if docker ps | grep -q bencenet-app; then
    echo "Bencenet Bank container is running"
else
    echo "Bencenet Bank container is not running"
    echo "All containers:"
    docker ps -a
    echo "Container logs:"
    docker logs bencenet-app || true
    exit 1
fi

# Test health endpoint
echo "Testing health endpoint..."
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/health || echo "000")

if [ "$response" -eq 200 ]; then
    echo "Bencenet Bank health check passed (HTTP 200)"
    
    # Additional validation - check environment in health response
    env_check=$(curl -s http://localhost:80/health | grep -o '"environment":"[^"]*"' || echo "")
    echo "Environment: $env_check"
    
    exit 0
else
    echo "Bencenet Bank health check failed (HTTP $response)"
    echo "Testing root endpoint:"
    curl -v http://localhost:80/ || true
    echo "Container logs:"
    docker logs bencenet-app
    exit 1
fi