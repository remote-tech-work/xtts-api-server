#!/bin/bash

# XTTS API Server Deployment Script
# This script handles deployment to AWS spot instance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ELASTIC_IP="35.80.239.175"
SSH_KEY_PATH=""  # Will be set by user
DOCKER_IMAGE="xtts-api-server"
REMOTE_USER="ubuntu"

# Functions
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_help() {
    echo "XTTS API Server Deployment Script"
    echo ""
    echo "Usage: ./deploy.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -k, --key PATH         Path to SSH private key (required)"
    echo "  -i, --ip IP           Elastic IP address (default: 35.80.239.175)"
    echo "  -t, --tag TAG         Docker image tag (default: latest)"
    echo "  -b, --build           Build Docker image locally before deploying"
    echo "  -d, --deepspeed       Enable DeepSpeed optimization"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh -k ~/.ssh/my-key.pem"
    echo "  ./deploy.sh -k ~/.ssh/my-key.pem -b -t v1.0.0"
    echo "  ./deploy.sh -k ~/.ssh/my-key.pem -d"
}

# Parse arguments
BUILD_LOCAL=false
DEEPSPEED=false
TAG="latest"

while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--key)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        -i|--ip)
            ELASTIC_IP="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -b|--build)
            BUILD_LOCAL=true
            shift
            ;;
        -d|--deepspeed)
            DEEPSPEED=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate SSH key
if [ -z "$SSH_KEY_PATH" ]; then
    print_error "SSH key path is required!"
    show_help
    exit 1
fi

if [ ! -f "$SSH_KEY_PATH" ]; then
    print_error "SSH key file not found: $SSH_KEY_PATH"
    exit 1
fi

# Test SSH connection
print_status "Testing SSH connection to $ELASTIC_IP..."
if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$REMOTE_USER@$ELASTIC_IP" "echo 'Connected successfully'" > /dev/null 2>&1; then
    print_error "Failed to connect to $ELASTIC_IP"
    print_warning "Make sure the instance is running and the security group allows SSH access"
    exit 1
fi

print_status "SSH connection successful!"

# Build Docker image if requested
if [ "$BUILD_LOCAL" = true ]; then
    print_status "Building Docker image locally..."
    docker build -f Dockerfile.production -t "$DOCKER_IMAGE:$TAG" .

    print_status "Saving Docker image..."
    docker save "$DOCKER_IMAGE:$TAG" | gzip > "xtts-api-server-$TAG.tar.gz"

    print_status "Uploading Docker image to server..."
    scp -i "$SSH_KEY_PATH" "xtts-api-server-$TAG.tar.gz" "$REMOTE_USER@$ELASTIC_IP:/tmp/"

    print_status "Loading Docker image on server..."
    ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$ELASTIC_IP" "docker load < /tmp/xtts-api-server-$TAG.tar.gz && rm /tmp/xtts-api-server-$TAG.tar.gz"

    rm "xtts-api-server-$TAG.tar.gz"
fi

# Create deployment script
cat > /tmp/deploy_remote.sh <<EOF
#!/bin/bash
set -e

echo "Starting deployment..."

# Create directories if they don't exist
mkdir -p ~/xtts-api-server/speakers
mkdir -p ~/xtts-api-server/output
mkdir -p ~/xtts-api-server/models
mkdir -p ~/xtts-api-server/nginx/ssl

cd ~/xtts-api-server

# Create docker-compose.production.yml
cat > docker-compose.production.yml <<'COMPOSE_EOF'
version: '3.8'

services:
  xtts-api:
    image: $DOCKER_IMAGE:$TAG
    container_name: xtts-api-server
    ports:
      - "8020:8020"
    volumes:
      - ./speakers:/app/speakers
      - ./output:/app/output
      - ./models:/app/xtts_models
    environment:
      - DEVICE=cuda
      - USE_CACHE=true
      - DEEPSPEED=$DEEPSPEED
      - MODEL_SOURCE=local
      - MODEL_VERSION=v2.0.2
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8020/languages"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
COMPOSE_EOF

# Stop existing container
docker-compose -f docker-compose.production.yml down || true

# Pull latest image (if not built locally)
if [ "$BUILD_LOCAL" != "true" ]; then
    docker pull $DOCKER_IMAGE:$TAG
fi

# Start container
docker-compose -f docker-compose.production.yml up -d

# Wait for service to be healthy
echo "Waiting for service to start..."
sleep 10

for i in {1..30}; do
    if curl -f http://localhost:8020/languages > /dev/null 2>&1; then
        echo "Service is healthy!"
        break
    fi
    echo "Attempt \$i/30 - Service not ready yet..."
    sleep 5
done

# Show logs
echo ""
echo "Recent logs:"
docker-compose -f docker-compose.production.yml logs --tail=50

echo ""
echo "Deployment complete!"
echo "API is available at: http://$ELASTIC_IP:8020"
EOF

# Copy and execute deployment script
print_status "Deploying to server..."
scp -i "$SSH_KEY_PATH" /tmp/deploy_remote.sh "$REMOTE_USER@$ELASTIC_IP:/tmp/"
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$ELASTIC_IP" "bash /tmp/deploy_remote.sh"

# Clean up
rm /tmp/deploy_remote.sh

# Test the API
print_status "Testing API endpoint..."
if curl -f "http://$ELASTIC_IP:8020/languages" > /dev/null 2>&1; then
    print_status "API is working!"
else
    print_warning "API test failed. Check the logs on the server."
fi

echo ""
print_status "Deployment completed successfully!"
echo ""
echo "=========================================="
echo "XTTS API Server deployed to: http://$ELASTIC_IP:8020"
echo "API Documentation: http://$ELASTIC_IP:8020/docs"
echo ""
echo "To check logs:"
echo "  ssh -i $SSH_KEY_PATH $REMOTE_USER@$ELASTIC_IP"
echo "  docker logs xtts-api-server"
echo "=========================================="