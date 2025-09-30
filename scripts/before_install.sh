#!/bin/bash

set -e

echo "Starting BeforeInstall hook..."
exec > >(tee /var/log/before_install.log) 2>&1

echo "Stopping existing Bencenet Bank container..."
docker stop bencenet-app || echo "No running bencenet-app container found"
docker rm bencenet-app || echo "No bencenet-app container to remove"

echo "BeforeInstall hook completed successfully."