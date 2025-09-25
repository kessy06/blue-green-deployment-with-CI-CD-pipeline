# Update the validate_service.sh file
cat > scripts/validate_service.sh << 'EOF'
#!/bin/bash
set -e
set -x  # Enable debug output

echo "Starting ValidateService hook..."

# Wait for application to start
echo "Waiting 45 seconds for application to fully initialize..."
sleep 45

# Check if Docker is running
echo "Checking Docker service status..."
systemctl status docker || true

# Check if container is running
echo "Checking if zenith-app container is running..."
if docker ps | grep -q zenith-app; then
    echo "✓ Container is running"
    docker ps | grep zenith-app
else
    echo "✗ Container is not running"
    echo "Checking all containers:"
    docker ps -a
    echo "Checking container logs:"
    docker logs zenith-app || true
    exit 1
fi

# Check container health status
echo "Checking container health..."
container_status=$(docker inspect --format='{{.State.Status}}' zenith-app)
echo "Container status: $container_status"

if [ "$container_status" != "running" ]; then
    echo "✗ Container is not in running state"
    echo "Container logs:"
    docker logs zenith-app
    exit 1
fi

# Check if port 80 is listening
echo "Checking if port 80 is listening..."
if docker exec zenith-app netstat -tlnp | grep :80; then
    echo "✓ Port 80 is listening"
else
    echo "✗ Port 80 is not listening"
    echo "All listening ports in container:"
    docker exec zenith-app netstat -tlnp || true
fi

# Test health endpoint with multiple attempts
echo "Testing health endpoint..."
max_attempts=5
attempt=1

while [ $attempt -le $max_attempts ]; do
    echo "Health check attempt $attempt of $max_attempts..."
    
    # Test health endpoint
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/health 2>/dev/null || echo "000")
    echo "Health endpoint response: HTTP $response"
    
    if [ "$response" -eq 200 ]; then
        echo "✓ Health check passed (HTTP 200)"
        
        # Test root endpoint too
        root_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/ 2>/dev/null || echo "000")
        echo "Root endpoint response: HTTP $root_response"
        
        echo "ValidateService hook completed successfully."
        exit 0
    else
        echo "⚠ Health check failed (HTTP $response), attempt $attempt of $max_attempts"
        
        # Show detailed curl output for debugging
        echo "Detailed curl output:"
        curl -v http://localhost:80/health || true
        
        if [ $attempt -eq $max_attempts ]; then
            echo "✗ All health check attempts failed"
            echo "Final container logs:"
            docker logs --tail 50 zenith-app
            exit 1
        fi
        
        echo "Waiting 10 seconds before retry..."
        sleep 10
    fi
    
    attempt=$((attempt + 1))
done
EOF

