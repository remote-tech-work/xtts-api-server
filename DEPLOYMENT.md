# XTTS API Server - AWS Deployment Guide

This guide covers deploying the XTTS API Server to AWS using GPU-enabled spot instances with Docker and GitHub Actions.

## 📋 Prerequisites

- AWS Account with appropriate permissions
- Docker Hub account (for image registry)
- GitHub repository with Actions enabled
- AWS CLI configured locally
- SSH key pair for EC2 instances

## 🏗️ Architecture Overview

- **Instance Type**: g4dn.xlarge (1x NVIDIA T4 GPU, 4 vCPU, 16GB RAM)
- **OS**: Ubuntu 22.04 LTS with NVIDIA drivers
- **Container**: Docker with NVIDIA Container Toolkit
- **Networking**: Elastic IP (35.80.239.175)
- **Storage**: 100GB GP3 EBS volume
- **Deployment**: GitHub Actions CI/CD

## 🚀 Quick Start

### 1. Set up GitHub Secrets

Add these secrets to your GitHub repository:

```
AWS_ACCESS_KEY_ID        # AWS access key
AWS_SECRET_ACCESS_KEY    # AWS secret key
DOCKER_USERNAME          # Docker Hub username
DOCKER_PASSWORD          # Docker Hub password
SLACK_WEBHOOK           # Optional: Slack notifications
```

### 2. Launch Spot Instance

```bash
# Make script executable
chmod +x deploy/aws/launch-spot-instance.sh

# Update configuration in the script:
# - KEY_NAME: Your AWS key pair name
# - AMI_ID: Ubuntu 22.04 with NVIDIA (region-specific)
# - REGION: Your AWS region

# Launch instance
./deploy/aws/launch-spot-instance.sh
```

### 3. Deploy Manually

```bash
# Make deploy script executable
chmod +x deploy/deploy.sh

# Deploy to production
./deploy/deploy.sh -k ~/.ssh/your-key.pem

# Deploy with custom tag
./deploy/deploy.sh -k ~/.ssh/your-key.pem -t v1.0.0

# Deploy with DeepSpeed enabled
./deploy/deploy.sh -k ~/.ssh/your-key.pem -d
```

### 4. Automated Deployment

Push to the `main` or `production` branch to trigger automatic deployment:

```bash
git push origin main
```

## 🐳 Docker Configuration

### Production Dockerfile

The `Dockerfile.production` is optimized for GPU inference:

- Multi-stage build for smaller image size
- CUDA 11.8 support
- Pre-downloaded models
- Health checks included
- DeepSpeed ready

### Building Locally

```bash
# Build for x86_64 (AWS)
docker buildx build --platform linux/amd64 -f Dockerfile.production -t xtts-api-server:latest .

# Test locally (CPU mode)
docker run -p 8020:8020 -e DEVICE=cpu xtts-api-server:latest
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEVICE` | `cuda` | Computing device (cuda/cpu) |
| `USE_CACHE` | `true` | Enable result caching |
| `DEEPSPEED` | `false` | Enable DeepSpeed optimization |
| `MODEL_VERSION` | `v2.0.2` | XTTS model version |
| `LOWVRAM_MODE` | `false` | Low VRAM mode |

### Security Group Rules

| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 22 | TCP | Your IP | SSH access |
| 8020 | TCP | 0.0.0.0/0 | API endpoint |
| 80 | TCP | 0.0.0.0/0 | HTTP (optional) |
| 443 | TCP | 0.0.0.0/0 | HTTPS (optional) |

## 📊 Performance Optimization

### GPU Acceleration

- **g4dn.xlarge**: ~3-5x faster than CPU
- **g4dn.2xlarge**: ~4-6x faster (2x T4 GPUs)
- **p3.2xlarge**: ~8-10x faster (V100 GPU)

### DeepSpeed

Enable DeepSpeed for 2-3x additional speedup:

```bash
./deploy/deploy.sh -k ~/.ssh/key.pem -d
```

### Caching

Results are cached by default. Disable if needed:

```yaml
environment:
  - USE_CACHE=false
```

## 💰 Cost Optimization

### Spot Instance Savings

- Spot instances: ~70% cheaper than on-demand
- g4dn.xlarge spot: ~$0.15-0.30/hour
- g4dn.xlarge on-demand: ~$0.52/hour

### Auto-recovery from Spot Termination

The launch script includes:
- Spot request with max price
- Auto-restart on termination
- Elastic IP reassociation
- Model persistence on EBS

### Cost Monitoring

```bash
# Check current spot prices
aws ec2 describe-spot-price-history \
  --instance-types g4dn.xlarge \
  --product-descriptions "Linux/UNIX" \
  --max-results 10
```

## 🔍 Monitoring & Debugging

### Check Logs

```bash
# SSH into instance
ssh -i ~/.ssh/your-key.pem ubuntu@35.80.239.175

# View Docker logs
docker logs xtts-api-server

# Follow logs
docker logs -f xtts-api-server

# Check container status
docker ps -a
```

### Health Checks

```bash
# Check API health
curl http://35.80.239.175:8020/languages

# Check GPU status
ssh -i ~/.ssh/key.pem ubuntu@35.80.239.175 nvidia-smi
```

### Performance Metrics

```bash
# Monitor GPU usage
watch -n 1 nvidia-smi

# Check Docker stats
docker stats xtts-api-server
```

## 🧪 Testing

### Local Testing

```bash
# Open local test page
open test_tts.html
```

### Production Testing

```bash
# Open production test page
open test_tts_production.html

# Or test via curl
curl -X POST http://35.80.239.175:8020/tts_to_audio/ \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello from production server",
    "speaker_wav": "example/female.wav",
    "language": "en"
  }' \
  --output test.wav
```

## 🔄 Backup & Recovery

### Model Backup

```bash
# Backup models to S3
aws s3 sync /home/ubuntu/xtts-api-server/models s3://your-bucket/xtts-models/
```

### Volume Snapshot

```bash
# Create EBS snapshot
aws ec2 create-snapshot \
  --volume-id vol-xxxxx \
  --description "XTTS models backup"
```

## 🚨 Troubleshooting

### Common Issues

1. **GPU not detected**
   ```bash
   # Check NVIDIA drivers
   nvidia-smi
   # Reinstall NVIDIA Container Toolkit if needed
   ```

2. **Model download fails**
   ```bash
   # Increase Docker timeout
   # Check disk space: df -h
   ```

3. **API not accessible**
   ```bash
   # Check security group rules
   # Verify elastic IP association
   # Check Docker container status
   ```

4. **Spot instance terminated**
   ```bash
   # Run launch script again
   # Consider higher max price
   # Use persistent spot request
   ```

## 📚 Additional Resources

- [AWS Spot Instances Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-best-practices.html)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [Docker GPU Support](https://docs.docker.com/config/containers/resource_constraints/#gpu)
- [XTTS Documentation](https://github.com/coqui-ai/TTS)

## 🔐 Security Considerations

1. **API Authentication**: Consider adding API key authentication for production
2. **HTTPS**: Use nginx reverse proxy with SSL certificates
3. **Rate Limiting**: Implement rate limiting to prevent abuse
4. **Monitoring**: Set up CloudWatch alarms for unusual activity
5. **Backups**: Regular EBS snapshots for model persistence

## 📈 Scaling

For high-traffic scenarios:

1. **Load Balancer**: Use ALB with multiple instances
2. **Auto Scaling**: Configure auto-scaling groups
3. **ECS/EKS**: Consider container orchestration
4. **Model Caching**: Use Redis/ElastiCache for results
5. **CDN**: CloudFront for static assets

---

For support and updates, check the [main repository](https://github.com/daswer123/xtts-api-server).