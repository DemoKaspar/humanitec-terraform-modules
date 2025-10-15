#!/bin/bash
set -e

# Update system
apt-get update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Create Docker Compose file for the application
cat > docker-compose.yml << EOF
version: '3.8'
services:
  app:
    image: ${container_image}
    ports:
      - "80:${container_port}"
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - PORT=${container_port}
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:${container_port}/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

# Start the application
docker-compose up -d

# Set up log rotation and monitoring
echo "Application deployment completed for ${app_id} in ${env_id} environment"