# Use the official Node.js runtime as base image with specific version for better caching
FROM public.ecr.aws/lambda/nodejs:18

# Set the working directory in the container
WORKDIR /var/task

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