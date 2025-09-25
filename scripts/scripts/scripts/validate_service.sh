# scripts/validate_service.sh
#!/bin/bash
set -e

echo "Starting ValidateService hook..."

# Wait for the application to fully initialize
echo "Waiting for application initialization..."
sleep 30

# Check if container is running
echo "Checking if container is running..."
if docker ps | grep -q zenith-app; then
    echo "✓ Container is running"
else
    echo "✗ Container is not running"
    docker logs zenith-app || true
    exit 1
fi

# Check container health
echo "Checking container health..."
container_status=$(docker inspect --format='{{.State.Status}}' zenith-app)
if [ "$container_status" = "running" ]; then
    echo "✓ Container is healthy"
else
    echo "✗ Container is not healthy (Status: $container_status)"
    docker logs zenith-app || true
    exit 1
fi

# Test health endpoint multiple times for reliability
echo "Testing health endpoint..."
max_attempts=5
attempt=1

while [ $attempt -le $max_attempts ]; do
    echo "Health check attempt $attempt of $max_attempts..."
    
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/health || echo "000")
    
    if [ "$response" -eq 200 ]; then
        echo "✓ Health check passed (HTTP 200)"
        
        # Additional endpoint tests
        echo "Testing root endpoint..."
        root_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/ || echo "000")
        if [ "$root_response" -eq 200 ]; then
            echo "✓ Root endpoint accessible (HTTP 200)"
        else
            echo "⚠ Root endpoint returned HTTP $root_response"
        fi
        
        echo "ValidateService hook completed successfully."
        exit 0
    else
        echo "⚠ Health check failed (HTTP $response), attempt $attempt of $max_attempts"
        if [ $attempt -eq $max_attempts ]; then
            echo "✗ All health check attempts failed"
            echo "Checking application logs..."
            docker logs zenith-app || true
            exit 1
        fi
        sleep 10
    fi
    
    attempt=$((attempt + 1))
done