FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies for FreeSWITCH and audio processing
RUN apt-get update && apt-get install -y \
    gcc \
    libc6-dev \
    libffi-dev \
    libssl-dev \
    portaudio19-dev \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt requirements-test.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 freeswitch && chown -R freeswitch:freeswitch /app
USER freeswitch

# Expose ports
EXPOSE 8080 5060/udp 16384-32768/udp

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
CMD ["python", "src/main.py"]