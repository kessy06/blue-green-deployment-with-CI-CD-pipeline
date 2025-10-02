#!/bin/bash
set -e

echo "Starting ApplicationStop hook..."

# Stop existing Docker container
echo "Stopping existing Docker container..."
docker stop bencenet-app || true
docker rm bencenet-app || true

# Clean up old Docker images (keep last 3 versions)
echo "Cleaning up old Docker images..."
docker image prune -f || true

# Optional: Remove unused volumes
docker volume prune -f || true

echo "ApplicationStop hook completed successfully."