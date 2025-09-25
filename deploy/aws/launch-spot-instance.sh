#!/bin/bash

# AWS Spot Instance Launch Script for XTTS API Server
# This script launches a g4dn.xlarge spot instance with GPU support

set -e

# Configuration
INSTANCE_TYPE="g4dn.xlarge"
AMI_ID="ami-0143ff78595ef49f5"  # Ubuntu 22.04 LTS with NVIDIA drivers (update for your region)
KEY_NAME="finetuning"  # Replace with your key pair name
SECURITY_GROUP="sg-xtts-api"  # Will be created if doesn't exist
SUBNET_ID=""  # Optional: specify subnet ID
MAX_PRICE="0.30"  # Maximum spot price per hour
ELASTIC_IP_ALLOCATION_ID="eipalloc-053fa187bd3ca7c89"
REGION="us-west-2"  # Update to your region

# User data script to run on instance launch
USER_DATA=$(cat <<'EOF'
#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list

apt-get update
apt-get install -y nvidia-container-toolkit
systemctl restart docker

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app directory
mkdir -p /home/ubuntu/xtts-api-server
cd /home/ubuntu/xtts-api-server

# Clone repository
git clone https://github.com/daswer123/xtts-api-server.git .
chown -R ubuntu:ubuntu /home/ubuntu/xtts-api-server

# Create docker-compose.production.yml
cat > docker-compose.production.yml <<'COMPOSE'
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
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped
COMPOSE

# Pull and run the container
docker-compose -f docker-compose.production.yml pull
docker-compose -f docker-compose.production.yml up -d

# Setup auto-restart on reboot
cat > /etc/systemd/system/xtts-api.service <<'SERVICE'
[Unit]
Description=XTTS API Server
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/xtts-api-server
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable xtts-api.service

echo "XTTS API Server setup complete!"
EOF
)

# Create or update security group
echo "Creating security group..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ "$SECURITY_GROUP_ID" == "" ] || [ "$SECURITY_GROUP_ID" == "None" ]; then
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP \
        --description "Security group for XTTS API Server" \
        --region $REGION \
        --output text)

    # Add inbound rules
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region $REGION

    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 8020 \
        --cidr 0.0.0.0/0 \
        --region $REGION

    echo "Security group created: $SECURITY_GROUP_ID"
else
    echo "Using existing security group: $SECURITY_GROUP_ID"
fi

# Create spot instance request
echo "Requesting spot instance..."
REQUEST_ID=$(aws ec2 request-spot-instances \
    --spot-price "$MAX_PRICE" \
    --instance-count 1 \
    --type "one-time" \
    --launch-specification "{
        \"ImageId\": \"$AMI_ID\",
        \"InstanceType\": \"$INSTANCE_TYPE\",
        \"KeyName\": \"$KEY_NAME\",
        \"SecurityGroupIds\": [\"$SECURITY_GROUP_ID\"],
        \"UserData\": \"$(echo "$USER_DATA" | base64 -w 0)\",
        \"BlockDeviceMappings\": [
            {
                \"DeviceName\": \"/dev/sda1\",
                \"Ebs\": {
                    \"VolumeSize\": 100,
                    \"VolumeType\": \"gp3\",
                    \"DeleteOnTermination\": true
                }
            }
        ]
    }" \
    --region $REGION \
    --output text \
    --query 'SpotInstanceRequests[0].SpotInstanceRequestId')

echo "Spot instance request created: $REQUEST_ID"

# Wait for instance to be fulfilled
echo "Waiting for spot instance to be fulfilled..."
aws ec2 wait spot-instance-request-fulfilled \
    --spot-instance-request-ids $REQUEST_ID \
    --region $REGION

# Get instance ID
INSTANCE_ID=$(aws ec2 describe-spot-instance-requests \
    --spot-instance-request-ids $REQUEST_ID \
    --region $REGION \
    --query 'SpotInstanceRequests[0].InstanceId' \
    --output text)

echo "Instance launched: $INSTANCE_ID"

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running \
    --instance-ids $INSTANCE_ID \
    --region $REGION

# Associate elastic IP
echo "Associating elastic IP..."
aws ec2 associate-address \
    --instance-id $INSTANCE_ID \
    --allocation-id $ELASTIC_IP_ALLOCATION_ID \
    --region $REGION

# Tag the instance
aws ec2 create-tags \
    --resources $INSTANCE_ID \
    --tags Key=Name,Value=XTTS-API-Server Key=Environment,Value=Production \
    --region $REGION

# Get public IP
PUBLIC_IP="35.80.239.175"

echo "=========================================="
echo "Spot instance successfully launched!"
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "=========================================="
echo ""
echo "SSH into the instance:"
echo "ssh -i /path/to/$KEY_NAME.pem ubuntu@$PUBLIC_IP"
echo ""
echo "API will be available at:"
echo "http://$PUBLIC_IP:8020"
echo ""
echo "Note: It may take a few minutes for the server to be fully ready."