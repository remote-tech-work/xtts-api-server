#!/bin/bash

# Build Docker image on AWS spot instance with 200GB storage
# This avoids local disk space issues

set -e

# Configuration
ELASTIC_IP="35.80.239.175"
SSH_KEY_PATH=""
DOCKER_IMAGE_TAG="${1:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    echo "Build XTTS Docker image on AWS with 200GB storage"
    echo ""
    echo "Usage: $0 [OPTIONS] [IMAGE_TAG]"
    echo ""
    echo "Arguments:"
    echo "  IMAGE_TAG         Docker image tag (default: latest)"
    echo ""
    echo "Options:"
    echo "  -k, --key PATH    Path to SSH private key (required)"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -k ~/.ssh/finetuning.pem"
    echo "  $0 -k ~/.ssh/finetuning.pem v1.0.0"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--key)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            DOCKER_IMAGE_TAG="$1"
            shift
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

print_status "Building XTTS Docker image on AWS..."
print_status "Tag: $DOCKER_IMAGE_TAG"
print_status "Instance: $ELASTIC_IP"

# Test SSH connection
print_status "Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" ubuntu@"$ELASTIC_IP" "echo 'Connected'" > /dev/null 2>&1; then
    print_error "Cannot connect to AWS instance at $ELASTIC_IP"
    print_warning "Make sure:"
    print_warning "1. Instance is running"
    print_warning "2. Security group allows SSH from your IP"
    print_warning "3. SSH key is correct"
    exit 1
fi

print_status "SSH connection successful!"

# Create remote build script
print_status "Creating remote build script..."
cat > /tmp/remote-build.sh <<'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Docker build on AWS instance..."

# Show available space
echo "📊 Available disk space:"
df -h

# Navigate to app directory
cd /home/ubuntu/xtts-api-server || {
    echo "❌ App directory not found. Please deploy the code first."
    exit 1
}

# Pull latest code
echo "📥 Pulling latest code..."
git pull origin main || echo "No git repository or already up to date"

# Build with fallback strategy
echo "🐳 Building Docker image with 200GB available space..."

# Try production build first
echo "📦 Attempting production build (with DeepSpeed)..."
if docker build -f Dockerfile.production -t xtts-api-server:TAG . ; then
    echo "✅ Production build successful!"
    BUILD_TYPE="production"
elif docker build -f Dockerfile.simple -t xtts-api-server:TAG . ; then
    echo "✅ Simple build successful (without DeepSpeed)!"
    BUILD_TYPE="simple"
else
    echo "❌ Both builds failed!"
    echo "Checking logs..."
    docker system df
    df -h
    exit 1
fi

echo ""
echo "🎉 Build completed successfully!"
echo "Build type: $BUILD_TYPE"
echo "Image: xtts-api-server:TAG"

# Test the built image
echo "🧪 Testing built image..."
if docker run --rm xtts-api-server:TAG python -c "import torch; from TTS.api import TTS; print('Image test successful!')"; then
    echo "✅ Image test passed!"
else
    echo "⚠️  Image test failed, but build completed"
fi

echo ""
echo "📊 Final disk usage:"
df -h
docker system df

echo ""
echo "🏁 Build complete! Image ready for deployment."
EOF

# Replace TAG placeholder with actual tag
sed -i.bak "s/TAG/$DOCKER_IMAGE_TAG/g" /tmp/remote-build.sh
rm /tmp/remote-build.sh.bak

# Upload and execute build script
print_status "Uploading build script to AWS instance..."
scp -i "$SSH_KEY_PATH" /tmp/remote-build.sh ubuntu@"$ELASTIC_IP":/tmp/

print_status "Executing remote build..."
ssh -i "$SSH_KEY_PATH" ubuntu@"$ELASTIC_IP" "chmod +x /tmp/remote-build.sh && /tmp/remote-build.sh"

# Clean up
rm /tmp/remote-build.sh

print_status "Docker image built successfully on AWS!"
print_status "Image: xtts-api-server:$DOCKER_IMAGE_TAG"
print_status "Location: AWS instance $ELASTIC_IP"

echo ""
echo "=========================================="
echo "🎉 BUILD COMPLETED SUCCESSFULLY!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Image is ready on AWS instance"
echo "2. Deploy with: docker-compose up -d"
echo "3. Test at: http://$ELASTIC_IP:8020"
echo ""
echo "To rebuild:"
echo "  $0 -k $SSH_KEY_PATH $DOCKER_IMAGE_TAG"