# Use an official NVIDIA base image with CUDA support
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# Set label for the docker image description
LABEL description="Docker image for xtts-api-server"

# Install required packages (avoid cache to reduce image size)
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    python3-dev portaudio19-dev libportaudio2 libasound2-dev libportaudiocpp0 \
    git python3 python3-pip make g++ ffmpeg curl wget \
    gfortran libopenblas-dev liblapack-dev && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip and install build tools
RUN python3 -m pip install --upgrade pip setuptools wheel

# Install PyTorch first with CUDA support
RUN pip install torch==2.1.1 torchaudio==2.1.1 --index-url https://download.pytorch.org/whl/cu121

# Install numpy and scipy with specific versions
RUN pip install numpy==1.24.3 scipy==1.11.4

# Install coqpit with specific working version BEFORE TTS
RUN pip install "coqpit>=0.0.16,<0.0.18"

# Install trainer (required by TTS)
RUN pip install trainer==0.0.36

# Install TTS - let it manage its own dependencies
RUN pip install TTS==0.22.0

# Install deepspeed for GPU optimization
RUN pip install deepspeed==0.14.0

# Install language processing dependencies
RUN pip install spacy==3.7.2
# Download spacy model using direct URL to avoid version issues
RUN pip install https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.7.0/en_core_web_sm-3.7.0-py3-none-any.whl

# Install Japanese language support with MeCab
RUN apt-get update && apt-get install -y mecab libmecab-dev mecab-ipadic-utf8 && rm -rf /var/lib/apt/lists/*
# Install unidic-lite (includes dictionary) and other Japanese packages
RUN pip install mecab-python3 unidic-lite fugashi cutlet

# Install other dependencies with specific versions
RUN pip install \
    PyAudio==0.2.14 \
    requests==2.31.0 \
    transformers==4.36.2 \
    pyttsx3==2.90 \
    stream2sentence==0.2.2 \
    pydub \
    python-dotenv \
    uuid6

# Install FastAPI and server dependencies
RUN pip install \
    fastapi>=0.104.1 \
    "uvicorn[standard]" \
    python-multipart \
    loguru \
    pydantic

# Finally install xtts-api-server (let it use already installed deps)
RUN pip install --no-deps xtts-api-server==0.9.0

# Create necessary directories
RUN mkdir -p /xtts-server/speakers /xtts-server/output /xtts-server/models

# Expose the container ports
EXPOSE 8020

# Set environment variables for better defaults
ENV PYTHONUNBUFFERED=1
ENV CUDA_VISIBLE_DEVICES=0

# Run xtts_api_server when the container starts with CORS enabled for external access
CMD ["python3", "-m", "xtts_api_server", "--listen", "-p", "8020", "-t", "http://0.0.0.0:8020", "-sf", "/xtts-server/speakers", "-o", "/xtts-server/output", "-mf", "/xtts-server/models", "--deepspeed"]
