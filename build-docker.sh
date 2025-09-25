#!/bin/bash

# Docker build script with fallback
# Tries production Dockerfile first, falls back to simple version if it fails

set -e

IMAGE_NAME="${1:-xtts-api-server}"
TAG="${2:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

echo "🐳 Building Docker image: $FULL_IMAGE"

# Function to build with specific Dockerfile
build_with_dockerfile() {
    local dockerfile=$1
    local description=$2

    echo "📦 Attempting build with $description..."

    if docker build -f "$dockerfile" -t "$FULL_IMAGE" . ; then
        echo "✅ Successfully built with $description"
        return 0
    else
        echo "❌ Build failed with $description"
        return 1
    fi
}

# Try production Dockerfile first
if build_with_dockerfile "Dockerfile.production" "production Dockerfile (with DeepSpeed)"; then
    echo "🎉 Production build successful!"
    USED_DOCKERFILE="Dockerfile.production"
elif build_with_dockerfile "Dockerfile.simple" "simple Dockerfile (without DeepSpeed)"; then
    echo "🎉 Simple build successful!"
    echo "⚠️  Note: DeepSpeed not included - performance may be slower"
    USED_DOCKERFILE="Dockerfile.simple"
else
    echo "❌ Both builds failed!"
    echo ""
    echo "Troubleshooting:"
    echo "1. Make sure Docker is running"
    echo "2. Check that you have enough disk space"
    echo "3. Try building on a different architecture"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Docker image built successfully!"
echo "Image: $FULL_IMAGE"
echo "Dockerfile used: $USED_DOCKERFILE"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Test locally:"
echo "   docker run -p 8020:8020 -e DEVICE=cpu $FULL_IMAGE"
echo ""
echo "2. Push to registry:"
echo "   docker push $FULL_IMAGE"
echo ""
echo "3. Deploy to production:"
echo "   ./deploy/deploy.sh -k ~/.ssh/your-key.pem"