#!/bin/bash

# AI Receptionist Installation Script
# This script sets up the complete AI Receptionist platform

set -e

echo "🤖 AI Receptionist Installation Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking system requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed. Please install Git first."
        exit 1
    fi
    
    # Check available disk space (need at least 10GB)
    available_space=$(df . | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 10485760 ]; then  # 10GB in KB
        log_warning "Less than 10GB disk space available. Installation may fail."
    fi
    
    log_success "All requirements met!"
}

setup_environment() {
    log_info "Setting up environment configuration..."
    
    if [ ! -f .env ]; then
        cp .env.example .env
        log_success "Created .env file from template"
        log_warning "Please edit .env file with your specific configuration"
    else
        log_info ".env file already exists"
    fi
    
    # Create necessary directories
    mkdir -p backend/uploads
    mkdir -p backend/temp
    mkdir -p backend/models
    mkdir -p logs
    mkdir -p deployment/nginx/ssl
    
    log_success "Environment setup complete!"
}

download_models() {
    log_info "Downloading AI models..."
    
    # Download Whisper model
    if [ ! -f backend/models/ggml-base.en.bin ]; then
        log_info "Downloading Whisper model..."
        curl -L -o backend/models/ggml-base.en.bin \
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
        log_success "Whisper model downloaded!"
    else
        log_info "Whisper model already exists"
    fi
}

build_services() {
    log_info "Building Docker services..."
    
    # Build all services
    docker-compose -f deployment/docker-compose.yml build
    
    log_success "All services built successfully!"
}

start_core_services() {
    log_info "Starting core services..."
    
    # Start database and dependencies first
    docker-compose -f deployment/docker-compose.yml up -d postgres redis ollama
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 30
    
    # Check if services are running
    if docker-compose -f deployment/docker-compose.yml ps | grep -q "Up"; then
        log_success "Core services started successfully!"
    else
        log_error "Some services failed to start. Check logs with: docker-compose logs"
        exit 1
    fi
}

setup_ollama() {
    log_info "Setting up Ollama and downloading LLM..."
    
    # Wait for Ollama to be ready
    sleep 10
    
    # Pull LLaMA model
    log_info "Downloading LLaMA model (this may take several minutes)..."
    docker-compose -f deployment/docker-compose.yml exec -T ollama ollama pull llama3:8b
    
    log_success "Ollama setup complete!"
}

start_all_services() {
    log_info "Starting all services..."
    
    # Start all remaining services
    docker-compose -f deployment/docker-compose.yml up -d
    
    # Wait for all services
    sleep 20
    
    log_success "All services started!"
}

setup_rasa() {
    log_info "Setting up Rasa conversation engine..."
    
    # Wait for Rasa to be ready and train initial model
    sleep 10
    
    # Train Rasa model (if needed)
    docker-compose -f deployment/docker-compose.yml exec -T rasa rasa train
    
    log_success "Rasa setup complete!"
}

create_test_business() {
    log_info "Creating test business..."
    
    # Wait for backend to be ready
    sleep 15
    
    # Create a test business
    curl -X POST http://localhost:8000/businesses \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Test Business",
            "phone_number": "+1234567890",
            "welcome_message": "Hello! Thank you for calling Test Business. How can I help you today?",
            "voice_config": {
                "engine": "coqui",
                "model_name": "tts_models/en/ljspeech/tacotron2-DDC",
                "speed": 1.0
            },
            "rasa_config": {
                "model_path": "/app/models",
                "confidence_threshold": 0.7
            }
        }' 2>/dev/null || log_warning "Could not create test business automatically"
    
    log_success "Installation complete!"
}

run_health_checks() {
    log_info "Running health checks..."
    
    # Check API health
    if curl -s http://localhost:8000/health > /dev/null; then
        log_success "Backend API is healthy"
    else
        log_warning "Backend API health check failed"
    fi
    
    # Check frontend
    if curl -s http://localhost:3000 > /dev/null; then
        log_success "Frontend is accessible"
    else
        log_warning "Frontend health check failed"
    fi
    
    # Show service status
    log_info "Service status:"
    docker-compose -f deployment/docker-compose.yml ps
}

show_completion_message() {
    echo ""
    echo "🎉 AI Receptionist Installation Complete!"
    echo "========================================"
    echo ""
    echo "Access your AI Receptionist platform:"
    echo "  📊 Dashboard: http://localhost:3000"
    echo "  🔧 API Docs:  http://localhost:8000/docs"
    echo "  📞 Asterisk:  http://localhost:8088"
    echo ""
    echo "Next steps:"
    echo "  1. Edit .env file with your SIP provider details"
    echo "  2. Configure your phone numbers in the dashboard"
    echo "  3. Test the system with a SIP phone"
    echo "  4. Customize conversation flows"
    echo ""
    echo "For help and documentation:"
    echo "  📚 Setup Guide: docs/setup/README.md"
    echo "  🐛 Troubleshooting: Check logs with 'docker-compose logs'"
    echo ""
    echo "Happy AI receptionist building! 🤖📞"
}

# Main installation flow
main() {
    check_requirements
    setup_environment
    download_models
    build_services
    start_core_services
    setup_ollama
    start_all_services
    setup_rasa
    create_test_business
    run_health_checks
    show_completion_message
}

# Handle interruption
trap 'log_error "Installation interrupted"; exit 1' INT

# Ask for confirmation
echo "This script will install the AI Receptionist platform with all dependencies."
echo "This may take 10-30 minutes depending on your internet connection."
read -p "Do you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

# Run main installation
main
