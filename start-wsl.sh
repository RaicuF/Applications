#!/bin/bash

# AI Log Analyzer - WSL Startup Script
# This script sets up and starts the application in WSL environment

set -e

echo "🚀 AI Log Analyzer - WSL Startup"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check WSL version
echo -e "\n📍 Checking WSL environment..."
if grep -qi microsoft /proc/version; then
    print_status "Running in WSL environment"
    WSL_VERSION=$(wsl.exe -l -v 2>/dev/null | grep -E "^\*" | awk '{print $4}' || echo "2")
    print_status "WSL Version detected: ${WSL_VERSION}"
else
    print_warning "Not running in WSL, but continuing anyway..."
fi

# Check required dependencies
echo -e "\n📦 Checking dependencies..."

# Check Docker
if command_exists docker; then
    print_status "Docker is installed"
    
    # Check if Docker daemon is running
    if docker info >/dev/null 2>&1; then
        print_status "Docker daemon is running"
    else
        print_warning "Docker daemon is not running. Starting Docker..."
        
        # Try to start Docker daemon in WSL
        if command_exists dockerd; then
            sudo service docker start 2>/dev/null || {
                print_warning "Trying alternative Docker start method..."
                sudo dockerd > /dev/null 2>&1 &
                sleep 5
            }
        else
            print_error "Docker daemon not found. Please ensure Docker Desktop is running on Windows"
            echo "You can install Docker Desktop from: https://www.docker.com/products/docker-desktop"
            exit 1
        fi
    fi
else
    print_error "Docker is not installed"
    echo "Installing Docker in WSL..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_warning "Docker installed. You may need to restart your WSL session"
fi

# Check Docker Compose
if command_exists docker-compose; then
    print_status "Docker Compose is installed"
elif docker compose version >/dev/null 2>&1; then
    print_status "Docker Compose (plugin) is installed"
    alias docker-compose='docker compose'
else
    print_error "Docker Compose is not installed"
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_status "Docker Compose installed"
fi

# Check Python
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_status "Python $PYTHON_VERSION is installed"
else
    print_warning "Python 3 is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv
fi

# Check Node.js
if command_exists node; then
    NODE_VERSION=$(node --version)
    print_status "Node.js $NODE_VERSION is installed"
else
    print_warning "Node.js is not installed. Installing..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Create necessary directories
echo -e "\n📁 Creating necessary directories..."
mkdir -p backend/tmp/uploads backend/tmp/exports
mkdir -p nginx/ssl
print_status "Directories created"

# Setup environment files
echo -e "\n🔧 Setting up environment files..."
if [ ! -f backend/.env ]; then
    cp backend/.env.example backend/.env
    print_warning "Created backend/.env from example. Please update with your API keys"
else
    print_status "backend/.env already exists"
fi

if [ ! -f frontend/.env.local ]; then
    echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > frontend/.env.local
    print_status "Created frontend/.env.local"
else
    print_status "frontend/.env.local already exists"
fi

# Function to get WSL IP address
get_wsl_ip() {
    ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1
}

WSL_IP=$(get_wsl_ip)
print_status "WSL IP Address: $WSL_IP"

# Start services based on argument
START_MODE=${1:-docker}

if [ "$START_MODE" = "docker" ]; then
    echo -e "\n🐳 Starting with Docker Compose..."
    
    # Stop any running containers
    docker-compose down 2>/dev/null || true
    
    # Pull Ollama model if needed
    echo "Pulling Ollama model (this may take a while on first run)..."
    docker-compose up -d ollama
    sleep 5
    docker-compose exec -T ollama ollama pull llama3.2 2>/dev/null || print_warning "Ollama model pull skipped"
    
    # Start all services
    docker-compose up -d
    
    print_status "All services started with Docker Compose"
    
elif [ "$START_MODE" = "local" ]; then
    echo -e "\n💻 Starting in local development mode..."
    
    # Start PostgreSQL
    if command_exists psql; then
        print_status "PostgreSQL found"
    else
        print_warning "Installing PostgreSQL..."
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib
        sudo service postgresql start
    fi
    
    # Start Redis
    if command_exists redis-server; then
        print_status "Redis found"
        sudo service redis-server start
    else
        print_warning "Installing Redis..."
        sudo apt-get install -y redis-server
        sudo service redis-server start
    fi
    
    # Setup Python virtual environment
    echo "Setting up Python environment..."
    cd backend
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install -r requirements.txt
    
    # Start backend
    print_status "Starting FastAPI backend..."
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
    BACKEND_PID=$!
    cd ..
    
    # Install frontend dependencies
    echo "Setting up frontend..."
    cd frontend
    npm install
    
    # Start frontend
    print_status "Starting Next.js frontend..."
    npm run dev &
    FRONTEND_PID=$!
    cd ..
    
    print_status "Services started in local development mode"
    echo "Backend PID: $BACKEND_PID"
    echo "Frontend PID: $FRONTEND_PID"
    
    # Save PIDs for stop script
    echo $BACKEND_PID > .backend.pid
    echo $FRONTEND_PID > .frontend.pid
    
elif [ "$START_MODE" = "hybrid" ]; then
    echo -e "\n🔀 Starting in hybrid mode (Docker for services, local for app)..."
    
    # Start only infrastructure services with Docker
    docker-compose up -d postgres redis ollama
    
    # Wait for services to be ready
    echo "Waiting for services to be ready..."
    sleep 10
    
    # Update backend .env for local development with Docker services
    sed -i 's|postgresql+asyncpg://.*|postgresql+asyncpg://loganalyzer:securepassword123@localhost/loganalyzer|' backend/.env
    sed -i 's|redis://.*|redis://localhost:6379|' backend/.env
    
    # Start backend locally
    cd backend
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install -r requirements.txt
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
    BACKEND_PID=$!
    cd ..
    
    # Start frontend locally
    cd frontend
    npm install
    npm run dev &
    FRONTEND_PID=$!
    cd ..
    
    print_status "Hybrid mode started"
    echo $BACKEND_PID > .backend.pid
    echo $FRONTEND_PID > .frontend.pid
fi

# Display access information
echo -e "\n${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ AI Log Analyzer is ready!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "📌 Access points:"
echo "   Frontend:  http://localhost:3000"
echo "   Backend:   http://localhost:8000"
echo "   API Docs:  http://localhost:8000/docs"
echo ""
echo "🌐 WSL Network Access (from Windows):"
echo "   Frontend:  http://$WSL_IP:3000"
echo "   Backend:   http://$WSL_IP:8000"
echo ""
echo "📝 Logs:"
if [ "$START_MODE" = "docker" ]; then
    echo "   docker-compose logs -f [service_name]"
else
    echo "   Check .backend.pid and .frontend.pid for process IDs"
fi
echo ""
echo "🛑 To stop all services:"
echo "   ./stop-wsl.sh"
echo ""

# Keep script running if in local/hybrid mode
if [ "$START_MODE" != "docker" ]; then
    echo "Press Ctrl+C to stop all services..."
    trap 'kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit' INT
    wait
fi