#!/bin/bash
set -e

# XTTS API Server - Instance Setup Script
# This script runs when the EC2 instance boots up

echo "🚀 Starting XTTS API Server setup..."

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install NVIDIA Container Toolkit
echo "🎮 Installing NVIDIA Container Toolkit..."
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list

apt-get update
apt-get install -y nvidia-container-toolkit
systemctl restart docker

# Install docker-compose
echo "📦 Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI (for deployment scripts)
echo "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Create app directory structure
echo "📁 Setting up application directories..."
mkdir -p /home/ubuntu/xtts-api-server/{speakers,output,models}
cd /home/ubuntu/xtts-api-server

# Create initial docker-compose file
cat > docker-compose.production.yml <<'EOF'
version: '3.8'

services:
  xtts-api:
    image: xtts-api-server:latest
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
      - DEEPSPEED=false
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
EOF

# Set proper permissions
chown -R ubuntu:ubuntu /home/ubuntu/xtts-api-server

# Create systemd service for auto-start
echo "⚙️ Creating systemd service..."
cat > /etc/systemd/system/xtts-api.service <<'EOF'
[Unit]
Description=XTTS API Server
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=ubuntu
WorkingDirectory=/home/ubuntu/xtts-api-server
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xtts-api.service

# Install additional utilities
echo "🔧 Installing additional utilities..."
apt-get install -y htop nvtop curl wget unzip

# Create GPU monitoring script
cat > /home/ubuntu/gpu-status.sh <<'EOF'
#!/bin/bash
echo "=== GPU Status ==="
nvidia-smi
echo ""
echo "=== Docker Container Status ==="
docker ps
echo ""
echo "=== XTTS API Health ==="
curl -s http://localhost:8020/languages || echo "API not responding"
EOF

chmod +x /home/ubuntu/gpu-status.sh
chown ubuntu:ubuntu /home/ubuntu/gpu-status.sh

# Create log rotation for Docker
cat > /etc/logrotate.d/docker-container <<'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 5
    daily
    compress
    size 10M
    missingok
    delaycompress
    copytruncate
}
EOF

# Set up auto-cleanup for old Docker images (weekly)
echo "🧹 Setting up Docker cleanup..."
cat > /home/ubuntu/docker-cleanup.sh <<'EOF'
#!/bin/bash
echo "Running Docker cleanup..."
docker system prune -af --volumes --filter "until=168h"
echo "Docker cleanup completed"
EOF

chmod +x /home/ubuntu/docker-cleanup.sh
chown ubuntu:ubuntu /home/ubuntu/docker-cleanup.sh

# Add to crontab
(crontab -u ubuntu -l 2>/dev/null; echo "0 2 * * 0 /home/ubuntu/docker-cleanup.sh >> /home/ubuntu/cleanup.log 2>&1") | crontab -u ubuntu -

# Create welcome message
cat > /home/ubuntu/.welcome <<'EOF'
🎙️ XTTS API Server Instance Ready!

Quick Commands:
  - Check status:     ~/gpu-status.sh
  - View logs:        docker logs xtts-api-server
  - Restart service:  sudo systemctl restart xtts-api
  - API docs:         curl http://localhost:8020/docs

Directories:
  - Speakers:   ~/xtts-api-server/speakers/
  - Output:     ~/xtts-api-server/output/
  - Models:     ~/xtts-api-server/models/

GPU Monitoring:
  - nvidia-smi
  - nvtop
EOF

# Add welcome message to .bashrc
echo "cat ~/.welcome" >> /home/ubuntu/.bashrc

echo "✅ XTTS API Server setup completed!"
echo "📝 Logs saved to /var/log/user-data.log"

# Signal that setup is complete
touch /home/ubuntu/setup-complete