# scripts/before_install.sh
#!/bin/bash
set -e

echo "Starting BeforeInstall hook..."

# Stop existing Docker container
echo "Stopping existing Docker container..."
docker stop zenith-app || true
docker rm zenith-app || true

# Clean up old images
echo "Cleaning up old Docker images..."
docker image prune -f || true

echo "BeforeInstall hook completed successfully."
