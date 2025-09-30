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

# Create public directory if it doesn't exist
RUN mkdir -p public

# Verify the application structure
RUN ls -la /app/
RUN ls -la /app/public/ || echo "Public directory is empty"

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "const http = require('http'); http.get('http://localhost:80/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1); })"

# Start the application
CMD ["node", "app.js"]