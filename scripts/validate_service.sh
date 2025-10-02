#!/bin/bash
set -e

echo "Starting ValidateService hook..."

# Wait for application to start
echo "Waiting 30 seconds for application to fully initialize..."
sleep 30

# Check if container is running
echo "Checking if bencenet-app container is running..."
if docker ps | grep -q bencenet-app; then
    echo "Container is running"
else
    echo "Container is not running"
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
    echo "Health check passed (HTTP 200)"
    exit 0
else
    echo "Health check failed (HTTP $response)"
    echo "Testing root endpoint:"
    curl -v http://localhost:80/ || true
    echo "Container logs:"
    docker logs bencenet-app
    exit 1
fi