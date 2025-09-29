#!/bin/bash

# Installation script for XTTS API Server deployment tools

set -e

echo "🚀 Installing XTTS API Server deployment tools..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Please create it first:"
    echo "   python -m venv venv"
    echo "   source venv/bin/activate  # Linux/Mac"
    echo "   venv\\Scripts\\activate     # Windows"
    exit 1
fi

# Check if virtual environment is activated
if [ -z "$VIRTUAL_ENV" ]; then
    echo "❌ Virtual environment not activated. Please activate it first:"
    echo "   source venv/bin/activate  # Linux/Mac"
    echo "   venv\\Scripts\\activate     # Windows"
    exit 1
fi

echo "✅ Virtual environment detected: $VIRTUAL_ENV"

# Install deployment dependencies
echo "📦 Installing deployment dependencies..."
pip install -r deploy/requirements.txt

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x deploy/aws/launch-spot-instance.sh
chmod +x deploy/aws/user-data.sh
chmod +x deploy/deploy.sh
chmod +x deploy/emergency_cleanup.py

echo "✅ Installation completed!"
echo ""
echo "Available tools:"
echo "  • deploy/aws/launch-spot-instance.sh  - Launch AWS spot instance"
echo "  • deploy/deploy.sh                    - Deploy to existing instance"
echo "  • deploy/emergency_cleanup.py         - Clean up all AWS resources"
echo ""
echo "Usage examples:"
echo "  ./deploy/aws/launch-spot-instance.sh"
echo "  ./deploy/deploy.sh -k ~/.ssh/key.pem"
echo "  python3 deploy/emergency_cleanup.py --list-only"