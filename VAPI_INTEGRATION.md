# Vapi.ai Integration Guide

This document explains how to integrate the XTTS API Server with Vapi.ai for custom text-to-speech (TTS) services.

## Overview

The XTTS API Server now includes dedicated endpoints for Vapi.ai integration, providing high-quality voice synthesis with GPU acceleration and voice cloning capabilities.

## Endpoints

### Main TTS Endpoint
```
POST /vapi/tts
```

**Request Format (JSON):**
```json
{
  "type": "voice-request",
  "text": "Text to synthesize",
  "sampleRate": 22050,
  "timestamp": 1234567890
}
```

**Response:**
- **Content-Type:** `application/octet-stream`
- **Body:** Raw PCM audio data (mono, 16-bit signed, little-endian)
- **Status:** 200 on success

### Health Check
```
GET /vapi/health
```

Returns server status and configuration information.

## Supported Features

- **Sample Rates:** 8000, 16000, 22050, 24000 Hz
- **Audio Format:** Raw PCM (mono, 16-bit signed)
- **Languages:** All XTTS supported languages (17 languages)
- **Voice Cloning:** Uses configurable default voice
- **GPU Acceleration:** CUDA with DeepSpeed optimization

## Configuration

### Environment Variables

Set these in your `.env` file or Docker environment:

```bash
# Default voice for Vapi.ai requests
VAPI_DEFAULT_SPEAKER=example/female.wav

# Default language for TTS
VAPI_DEFAULT_LANGUAGE=en

# Optional API key for authentication
VAPI_API_KEY=your_api_key_here
```

### Voice Configuration

1. **Using Example Voices:**
   - `example/female.wav` (default)
   - `example/male.wav`
   - `example/calm_female.wav`

2. **Custom Voices:**
   - Place WAV files in the `speakers/` directory
   - Set `VAPI_DEFAULT_SPEAKER` to your voice path
   - Requirements: WAV format, mono, 22050Hz, 7-9 seconds

## Vapi.ai Setup

1. **In Vapi.ai Dashboard:**
   - Go to Custom Voice settings
   - Select "Custom TTS Provider"
   - Enter your server URL: `https://your-server.com/vapi/tts`

2. **Server Requirements:**
   - Publicly accessible HTTPS endpoint
   - Response time under 30-45 seconds
   - Reliable uptime

3. **SSL/HTTPS:**
   - Vapi.ai requires HTTPS for production
   - Use a reverse proxy (nginx) or cloud load balancer
   - Configure SSL certificates

## Testing

Use the provided test script:

```bash
python test_vapi_integration.py
```

This tests:
- Health check endpoint
- TTS generation with different sample rates
- Error handling
- Audio quality verification

## Performance Optimization

### GPU Configuration
- Ensure CUDA is available: `DEVICE=cuda`
- Enable DeepSpeed: `DEEPSPEED=true`
- Use appropriate GPU memory: `LOWVRAM_MODE=false` for G4 instances

### Response Time Optimization
- Use voice caching: `USE_CACHE=true`
- Pre-load voice latents for default speaker
- Keep text length reasonable (< 1000 characters)

### Resource Management
- Monitor GPU memory usage
- Set appropriate worker processes
- Use background task cleanup for temporary files

## Troubleshooting

### Common Issues

1. **Audio Quality Problems:**
   - Check sample rate compatibility
   - Verify voice file quality
   - Test with different voice samples

2. **Timeout Issues:**
   - Monitor server performance
   - Check GPU utilization
   - Optimize text preprocessing

3. **Format Errors:**
   - Ensure PCM conversion is working
   - Verify mono audio output
   - Check byte order (little-endian)

### Debugging

Enable detailed logging:
```bash
# Check server logs
docker-compose logs -f

# Test individual components
curl -X GET http://your-server:8020/vapi/health
```

### Error Codes

- **400:** Bad request (invalid parameters)
- **500:** Server error (TTS generation failed)
- **200:** Success with PCM audio data

## AWS Production Setup

### Step 1: Configure Security Group

1. **In AWS EC2 Console:**
   - Go to Security Groups
   - Select your instance's security group
   - Add inbound rules:
     ```
     Type: Custom TCP
     Port: 8020
     Source: 0.0.0.0/0 (or restrict to Vapi.ai IPs)

     Type: HTTPS
     Port: 443
     Source: 0.0.0.0/0
     ```

### Step 2: Setup Domain and SSL

#### Option A: Using AWS Application Load Balancer (Recommended)

1. **Create Target Group:**
   ```
   - Protocol: HTTP
   - Port: 8020
   - Health check path: /vapi/health
   - Register your EC2 instance
   ```

2. **Create Application Load Balancer:**
   ```
   - Scheme: Internet-facing
   - Listeners: HTTPS (443)
   - Certificate: Request from AWS Certificate Manager
   - Target Group: Your created target group
   ```

3. **Configure Route 53:**
   ```
   - Create A record
   - Alias to Load Balancer
   - Domain: api.yourdomain.com
   ```

#### Option B: Using Nginx with Let's Encrypt

1. **Install Nginx on EC2:**
   ```bash
   sudo yum install -y nginx
   sudo systemctl start nginx
   sudo systemctl enable nginx
   ```

2. **Install Certbot:**
   ```bash
   sudo yum install -y certbot python3-certbot-nginx
   ```

3. **Configure Nginx:**
   ```bash
   sudo nano /etc/nginx/conf.d/vapi.conf
   ```

   Add configuration:
   ```nginx
   server {
       listen 80;
       server_name api.yourdomain.com;

       location / {
           return 301 https://$server_name$request_uri;
       }
   }

   server {
       listen 443 ssl;
       server_name api.yourdomain.com;

       # SSL will be configured by certbot

       # Vapi.ai endpoints
       location /vapi/ {
           proxy_pass http://localhost:8020/vapi/;
           proxy_http_version 1.1;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;

           # Important for Vapi.ai
           proxy_read_timeout 45s;
           proxy_connect_timeout 10s;

           # CORS headers
           add_header Access-Control-Allow-Origin "*" always;
           add_header Access-Control-Allow-Methods "POST, GET, OPTIONS" always;
           add_header Access-Control-Allow-Headers "*" always;

           # Handle OPTIONS for CORS preflight
           if ($request_method = 'OPTIONS') {
               return 204;
           }
       }

       # Optional: Proxy other endpoints
       location / {
           proxy_pass http://localhost:8020/;
           proxy_http_version 1.1;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

4. **Get SSL Certificate:**
   ```bash
   sudo certbot --nginx -d api.yourdomain.com
   ```

5. **Test and Reload:**
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

### Step 3: Configure Vapi.ai

1. **In Vapi.ai Dashboard:**
   - Navigate to **Providers** → **Custom TTS**
   - Click **Add Custom Provider**

2. **Configure Provider Settings:**
   ```
   Name: XTTS Turkish Voice
   URL: https://api.yourdomain.com/vapi/tts
   Method: POST
   Headers: (optional)
     - Content-Type: application/json
   ```

3. **Create Voice Configuration:**
   ```json
   {
     "provider": "custom",
     "providerId": "your-provider-id",
     "voice": "turkish-female",
     "settings": {
       "sampleRate": 22050
     }
   }
   ```

4. **Test in Vapi.ai:**
   - Use the Test Console
   - Select your custom TTS provider
   - Send test message: "Merhaba, Vapi entegrasyonu çalışıyor"

### Step 4: Monitoring and Optimization

1. **CloudWatch Monitoring (if using ALB):**
   ```bash
   # Monitor target health
   aws elbv2 describe-target-health \
     --target-group-arn your-target-group-arn
   ```

2. **Server Logs:**
   ```bash
   # Check Docker logs
   docker-compose logs -f | grep vapi

   # Check Nginx logs (if using)
   sudo tail -f /var/log/nginx/access.log
   sudo tail -f /var/log/nginx/error.log
   ```

3. **Performance Tuning:**
   ```bash
   # Update Docker environment for Turkish
   sudo nano docker/.env
   ```

   Set:
   ```env
   VAPI_DEFAULT_LANGUAGE=tr
   VAPI_DEFAULT_SPEAKER=example/female.wav
   USE_CACHE=true
   DEEPSPEED=true
   ```

### Step 5: Vapi.ai Integration Testing

1. **Test with Postman:**
   - Import the provided Postman collection
   - Update base URL to your HTTPS endpoint
   - Run health check and TTS tests

2. **Create Vapi Assistant:**
   ```javascript
   {
     "name": "Turkish Assistant",
     "voice": {
       "provider": "custom",
       "providerId": "your-xtts-provider-id"
     },
     "model": {
       "provider": "openai",
       "model": "gpt-4",
       "systemPrompt": "Sen Türkçe konuşan bir asistansın."
     }
   }
   ```

3. **Test Phone Call:**
   - Configure phone number in Vapi.ai
   - Make test call
   - Verify Turkish TTS quality

### Troubleshooting AWS Setup

#### SSL Certificate Issues:
```bash
# Check certificate
sudo certbot certificates

# Renew if needed
sudo certbot renew --dry-run
```

#### Connection Timeouts:
- Check Security Groups
- Verify Docker is running: `docker ps`
- Test locally: `curl http://localhost:8020/vapi/health`

#### Audio Quality Issues:
- Verify GPU is being used: `nvidia-smi`
- Check sample rate compatibility
- Monitor response times in CloudWatch

## Production Deployment

### Reverse Proxy Setup (nginx)

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location /vapi/ {
        proxy_pass http://localhost:8020/vapi/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 60s;
    }
}
```

### Docker Production Config

```yaml
services:
  xttsapiserver:
    image: xttsapiserver
    environment:
      - VAPI_DEFAULT_SPEAKER=your/voice.wav
      - VAPI_DEFAULT_LANGUAGE=en
      - DEVICE=cuda
      - DEEPSPEED=true
      - USE_CACHE=true
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['0']
              capabilities: [gpu]
```

## Custom Voice Setup

### Voice Preparation

1. **Record Voice Sample:**
   - 7-9 seconds of clear speech
   - Single speaker, no background noise
   - Natural conversational tone

2. **Audio Processing:**
   ```bash
   # Convert to required format
   ffmpeg -i input.mp3 -ar 22050 -ac 1 -sample_fmt s16 output.wav
   ```

3. **Upload to Server:**
   ```bash
   # Copy to speakers directory
   docker cp voice.wav container:/xtts-server/speakers/custom/voice.wav

   # Update environment
   VAPI_DEFAULT_SPEAKER=custom/voice.wav
   ```

## Monitoring

### Key Metrics
- Response time per request
- GPU memory usage
- Error rates
- Audio generation speed

### Health Checks
- `/vapi/health` endpoint status
- CUDA availability
- Model loading status

## Support

For issues specific to this integration:
1. Check server logs for TTS errors
2. Verify audio format compliance
3. Test with different voice samples
4. Monitor GPU performance

For Vapi.ai platform issues:
- Consult Vapi.ai documentation
- Check webhook delivery logs
- Verify HTTPS connectivity