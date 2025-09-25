# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

XTTS API Server is a FastAPI-based server for XTTSv2 text-to-speech synthesis. It provides REST API endpoints for generating speech from text using voice cloning technology.

## Development Commands

### Running the Server
```bash
# Standard mode (localhost:8020)
python -m xtts_api_server

# With GPU acceleration
python -m xtts_api_server --device cuda

# With DeepSpeed optimization (2-3x faster)
python -m xtts_api_server --deepspeed

# Low VRAM mode
python -m xtts_api_server --lowvram

# Streaming mode (local only)
python -m xtts_api_server --streaming-mode

# External access
python -m xtts_api_server --listen
```

### Installation
```bash
# Virtual environment setup
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate      # Windows

# Install dependencies
pip install -r requirements.txt

# GPU support (CUDA 11.8)
pip install torch==2.1.1+cu118 torchaudio==2.1.1+cu118 --index-url https://download.pytorch.org/whl/cu118
```

### Docker
```bash
# Build and run with docker-compose
cd docker
docker compose build
docker compose up
```

## Architecture

### Core Components

- **`server.py`**: FastAPI application with REST endpoints for TTS operations
- **`tts_funcs.py`**: `TTSWrapper` class handling model loading, voice synthesis, and caching
- **`__main__.py`**: CLI argument parser and server initialization
- **`modeldownloader.py`**: Model download and version management utilities
- **`RealtimeTTS/`**: Streaming TTS implementation for real-time audio generation

### Key API Endpoints

- `POST /tts_to_audio/`: Generate audio from text (returns WAV file)
- `POST /tts_to_file`: Generate and save audio to file system
- `GET /tts_stream`: HTTP streaming endpoint for chunked audio
- `GET /speakers_list`: List available voice samples
- `POST /switch_model`: Switch between different XTTS model versions
- `POST /set_tts_settings`: Configure synthesis parameters

### Model Management

The server supports three model sources (`--model-source`):
- `local`: Uses locally stored models with XttsConfig
- `apiManual`: Uses TTS API with manual model management
- `api`: Uses latest model version from TTS API

Models are stored in `xtts_models/` by default. Custom fine-tuned models should include `config.json`, `vocab.json`, and `model.pth`.

### Voice Samples

Voice samples are stored in `speakers/` folder. Samples should be:
- WAV format, mono, 22050Hz, 16-bit
- 7-9 seconds duration
- Clean audio without background noise
- Can use single file or folder with multiple samples

### Caching System

When `--use-cache` is enabled, synthesis results are cached in `output/cache.json` to avoid regenerating identical requests.

## Testing

Currently no automated test suite. Manual testing via:
- API documentation at http://localhost:8020/docs
- Example voice samples in `example/` directory

## Important Considerations

- Streaming mode only works locally and has limitations
- First run requires model download (~2GB)
- DeepSpeed installation is Python version-specific
- GPU memory usage varies by mode (standard ~4GB, streaming +2GB with improve flag)