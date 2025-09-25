# scripts/application_start.sh
#!/bin/bash
set -e

echo "Starting ApplicationStart hook..."

# Pull the latest Docker image
echo "Pulling latest Docker image..."
docker pull 647540925028.dkr.ecr.eu-west-2.amazonaws.com/zenith-bank-app:latest

if [ $? -eq 0 ]; then
    echo "✓ Docker image pulled successfully"
else
    echo "✗ Failed to pull Docker image"
    exit 1
fi

# Start the Docker container
echo "Starting Docker container..."
docker run -d \
  --name zenith-app \
  --restart unless-stopped \
  -p 80:80 \
  647540925028.dkr.ecr.eu-west-2.amazonaws.com/zenith-bank-app:latest

if [ $? -eq 0 ]; then
    echo "✓ Docker container started successfully"
else
    echo "✗ Failed to start Docker container"
    exit 1
fi

# Wait for application to start
echo "Waiting for application to start..."
sleep 15

echo "ApplicationStart hook completed successfully."
