# Use the official Node.js runtime as base image from public ECR
FROM public.ecr.aws/docker/library/node:18-alpine

# Set the working directory in the container
WORKDIR /app

# Copy package files first for better Docker layer caching
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy the entire application code including public directory
COPY . .

# Verify the public directory exists and list contents
RUN ls -la /app/
RUN ls -la /app/public/ || echo "Public directory not found"

# Expose port 80
EXPOSE 80

# Start the application
CMD ["node", "app.js"]