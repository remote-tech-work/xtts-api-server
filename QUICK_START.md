# XTTS API Server - Quick Start Guide

## 🚀 Current Status
✅ **Local server running** on http://localhost:8020
✅ **Docker build in progress** (fixing DeepSpeed issues)
✅ **AWS deployment ready** (GitHub Actions + manual scripts)
✅ **Emergency cleanup ready** (Python script)

## 🎯 Quick Commands

### Local Development
```bash
# Start local server
source venv/bin/activate
python -m xtts_api_server --host 0.0.0.0 --port 8020 --device cpu

# Test with browser
open test_tts.html
```

### Docker Build & Test

#### Local Build (if you have enough disk space)
```bash
# Build with fallback (handles DeepSpeed failures)
./build-docker.sh

# Test built image locally
docker run -p 8020:8020 -e DEVICE=cpu xtts-api-server:latest
```

#### AWS Build (recommended for disk space issues)
```bash
# First, launch AWS instance
./deploy/aws/launch-spot-instance.sh

# Build on AWS with 200GB storage
./deploy/build-on-aws.sh -k ~/.ssh/finetuning.pem

# Deploy the built image
./deploy/deploy.sh -k ~/.ssh/finetuning.pem
```

### AWS Deployment

#### Option 1: Automatic (GitHub Actions)
```bash
# Set GitHub secrets first:
# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, DOCKER_USERNAME, DOCKER_PASSWORD

# Deploy to main environment
git push origin main

# Deploy to development environment
git push origin development
```

#### Option 2: Manual Deployment
```bash
# Launch instance
./deploy/aws/launch-spot-instance.sh

# Deploy code
./deploy/deploy.sh -k ~/.ssh/finetuning.pem

# Test production
open test_tts_production.html
```

### Cleanup Everything
```bash
# List AWS resources (dry run)
python3 deploy/emergency_cleanup.py --list-only

# Clean up all AWS resources
python3 deploy/emergency_cleanup.py
```

## 📁 Key Files

| File | Purpose |
|------|---------|
| `test_tts.html` | Local testing interface |
| `test_tts_production.html` | Production testing (connects to 35.80.239.175) |
| `build-docker.sh` | Docker build with DeepSpeed fallback |
| `deploy/emergency_cleanup.py` | Clean up all AWS resources |
| `deploy/deploy.sh` | Manual deployment script |
| `Dockerfile.production` | GPU-optimized Docker build |
| `Dockerfile.simple` | Fallback Docker build (no DeepSpeed) |

## 🔧 Configuration

### GitHub Secrets Required
```
AWS_ACCESS_KEY_ID        # Your AWS access key
AWS_SECRET_ACCESS_KEY    # Your AWS secret key
DOCKER_USERNAME          # Docker Hub username
DOCKER_PASSWORD          # Docker Hub password
KEY_NAME                 # AWS key pair name (optional, defaults to 'finetuning')
AMI_ID                   # Ubuntu 22.04 AMI (optional, has default)
```

### Environment Variables
```bash
DEVICE=cuda              # Use GPU (cuda) or CPU (cpu)
USE_CACHE=true          # Enable result caching
DEEPSPEED=false         # Enable DeepSpeed optimization
MODEL_VERSION=v2.0.2    # XTTS model version
```

## 💰 Cost Management

### Spot Instance Savings
- **g4dn.xlarge spot**: ~$0.15-0.30/hour (~70% savings)
- **g4dn.xlarge on-demand**: ~$0.52/hour
- **Monthly estimate**: ~$100-200 if running 24/7

### Auto-cleanup Features
- Spot instance auto-recovery
- Weekly Docker cleanup (cron job)
- Emergency cleanup script for everything

## 🐛 Troubleshooting

### Common Issues

1. **DeepSpeed build fails**
   ```bash
   # Use simple build instead
   DOCKERFILE=Dockerfile.simple docker-compose build
   ```

2. **API not accessible**
   ```bash
   # Check security group allows port 8020
   # Verify elastic IP association
   curl http://35.80.239.175:8020/languages
   ```

3. **Model download slow**
   ```bash
   # First run downloads ~2GB model - be patient
   # Check logs: docker logs xtts-api-server
   ```

4. **GPU not detected**
   ```bash
   # SSH into instance and check
   nvidia-smi
   docker run --gpus all nvidia/cuda:11.8-runtime-ubuntu22.04 nvidia-smi
   ```

## 📊 Performance Expectations

| Configuration | Speed | Cost/Hour | Use Case |
|---------------|--------|-----------|----------|
| Local CPU | 1x | $0 | Development |
| Local GPU (MPS) | 2-3x | $0 | Development |
| g4dn.xlarge GPU | 4-6x | ~$0.20 | Production |
| g4dn.xlarge + DeepSpeed | 8-12x | ~$0.20 | High Performance |

## 🎉 Next Steps

1. **Wait for Docker build** to complete
2. **Test locally** with built image
3. **Push to GitHub** to trigger AWS deployment
4. **Monitor costs** via AWS billing dashboard
5. **Use cleanup script** when done testing

The system is designed to be cost-effective and fully automated while giving you complete control over resource cleanup!