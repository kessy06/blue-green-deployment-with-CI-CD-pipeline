#!/bin/bash
echo "Stopping existing Docker container..."
docker stop zenith-app || true
docker rm zenith-app || true
echo "Application stopped successfully."