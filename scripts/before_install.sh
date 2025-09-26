# scripts/before_install.sh
#!/bin/bash
set -e

echo "Stopping existing Docker container..."
docker stop bencenet-app || true
docker rm bencenet-app || true
echo "Application stopped successfully."