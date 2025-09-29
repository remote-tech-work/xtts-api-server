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