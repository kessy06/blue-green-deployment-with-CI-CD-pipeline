# scripts/after_install.sh  
#!/bin/bash
set -e

echo "Starting AfterInstall hook..."

# Login to ECR
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 647540925028.dkr.ecr.eu-west-2.amazonaws.com

if [ $? -eq 0 ]; then
    echo "✓ ECR login successful"
else
    echo "✗ ECR login failed"
    exit 1
fi

echo "AfterInstall hook completed successfully."
