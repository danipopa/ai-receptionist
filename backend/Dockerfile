FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    ffmpeg \
    portaudio19-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Whisper.cpp
RUN git clone https://github.com/ggerganov/whisper.cpp.git /opt/whisper.cpp \
    && cd /opt/whisper.cpp \
    && make \
    && mkdir -p /app/models

# Download Whisper model
RUN cd /opt/whisper.cpp \
    && curl -L -o /app/models/ggml-base.en.bin \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"

# Create directories
RUN mkdir -p /app/uploads /app/temp

# Copy application code
COPY . .

# Set environment variables
ENV WHISPER_EXECUTABLE=/opt/whisper.cpp/main
ENV WHISPER_MODEL_PATH=/app/models/ggml-base.en.bin
ENV UPLOAD_DIR=/app/uploads

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
