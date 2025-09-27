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

# Install system dependencies for scipy
RUN apt-get update && apt-get install -y gfortran libopenblas-dev liblapack-dev && rm -rf /var/lib/apt/lists/*

# Install PyTorch first with CUDA support
RUN pip install torch==2.1.1 torchaudio==2.1.1 --index-url https://download.pytorch.org/whl/cu121

# Install numpy and scipy
RUN pip install numpy==1.24.3 scipy==1.11.4

# Install coqpit with specific working version
RUN pip install "coqpit>=0.0.16,<0.0.18"

# Install trainer (required by TTS)
RUN pip install trainer==0.0.36

# Install TTS with all dependencies
RUN pip install TTS==0.22.0

# Install deepspeed
RUN pip install deepspeed==0.14.0

# Install xtts-api-server specific dependencies
RUN pip install coqui-tts[languages]==0.24.1 || pip install coqui-tts==0.24.1
RUN pip install cutlet pydub uuid spacy==3.7.2 stream2sentence==0.2.2
RUN pip install pyaudio==0.2.14 pyttsx3==2.90
RUN pip install "fugashi[unidic-lite]"
RUN pip install requests==2.31.0 transformers==4.36.2

# Install xtts-api-server
RUN pip install xtts-api-server==0.9.0

# Install API dependencies
RUN pip install pydantic loguru fastapi "uvicorn[standard]" python-multipart

# Create necessary directories
RUN mkdir -p /xtts-server/speakers /xtts-server/output /xtts-server/models

# Expose the container ports
EXPOSE 8020

# Run xtts_api_server when the container starts
CMD ["python3", "-m", "xtts_api_server", "--listen", "-p", "8020", "-sf", "/xtts-server/speakers", "-o", "/xtts-server/output", "-mf", "/xtts-server/models", "--deepspeed"]
