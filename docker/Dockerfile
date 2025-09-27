# Use an official NVIDIA base image with CUDA support
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# Set label for the docker image description
LABEL description="Docker image for xtts-api-server"

# Install required packages (avoid cache to reduce image size)
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    python3-dev portaudio19-dev libportaudio2 libasound2-dev libportaudiocpp0 \
    git python3 python3-pip make g++ ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip and install build tools
RUN python3 -m pip install --upgrade pip setuptools wheel

# Install PyTorch with specific versions for stability
RUN pip install torch==2.1.1 torchaudio==2.1.1 --index-url https://download.pytorch.org/whl/cu121

# Install dependencies in correct order with specific versions
# First install TTS without dependencies to avoid conflicts
RUN pip install --no-deps TTS==0.22.0

# Install coqpit with specific working version BEFORE other packages
RUN pip install "coqpit>=0.0.16,<0.0.18"

# Install other TTS dependencies
RUN pip install numpy scipy torch==2.1.1 torchaudio==2.1.1 --index-url https://download.pytorch.org/whl/cu121

# Install deepspeed
RUN pip install deepspeed==0.14.0

# Install remaining TTS dependencies
RUN pip install gruut pysbd inflect librosa transformers>=4.33.0 encodec num2words

# Finally install xtts-api-server
RUN pip install --no-deps xtts-api-server==0.9.0
RUN pip install pydantic loguru fastapi uvicorn[standard] python-multipart streaming-stt-nemo

# Create necessary directories
RUN mkdir -p /xtts-server/speakers /xtts-server/output /xtts-server/models

# Expose the container ports
EXPOSE 8020

# Run xtts_api_server when the container starts
CMD ["python3", "-m", "xtts_api_server", "--listen", "-p", "8020", "-sf", "/xtts-server/speakers", "-o", "/xtts-server/output", "-mf", "/xtts-server/models", "--deepspeed"]
