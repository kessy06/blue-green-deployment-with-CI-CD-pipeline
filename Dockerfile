# Use the official Node.js runtime as base image from public ECR
FROM public.ecr.aws/docker/library/node:18-alpine

# Set the working directory in the container
WORKDIR /app

# Copy package files first for better Docker layer caching
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy the rest of the application code
COPY . .

# Expose port 80
EXPOSE 80

# Start the application
CMD ["node", "app.js"]