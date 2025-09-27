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

# Install specific TTS version that works
RUN pip install TTS==0.22.0

# Install deepspeed with specific version
RUN pip install deepspeed==0.14.0

# Install xtts-api-server
RUN pip install xtts-api-server==0.9.0

# Create necessary directories
RUN mkdir -p /xtts-server/speakers /xtts-server/output /xtts-server/models

# Expose the container ports
EXPOSE 8020

# Run xtts_api_server when the container starts
CMD ["python3", "-m", "xtts_api_server", "--listen", "-p", "8020", "-sf", "/xtts-server/speakers", "-o", "/xtts-server/output", "-mf", "/xtts-server/models", "--deepspeed"]
