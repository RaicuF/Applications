#!/bin/bash

# AI Log Analyzer - Oracle Linux 8 WSL with Podman Startup Script
# Optimized for Oracle Linux 8 running in WSL with Podman

set -e

echo "🚀 AI Log Analyzer - Oracle Linux 8 WSL Startup"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check Oracle Linux WSL environment
echo -e "\n📍 Checking Oracle Linux WSL environment..."
if [ -f /etc/oracle-release ]; then
    ORACLE_VERSION=$(cat /etc/oracle-release)
    print_status "Running on $ORACLE_VERSION"
else
    print_warning "Oracle Linux release file not found, checking os-release..."
    if grep -q "Oracle Linux" /etc/os-release; then
        print_status "Oracle Linux detected via os-release"
    fi
fi

if grep -qi microsoft /proc/version; then
    print_status "Running in WSL environment"
else
    print_warning "Not running in WSL, but continuing anyway..."
fi

# Check Podman
echo -e "\n📦 Checking container runtime..."
if command_exists podman; then
    PODMAN_VERSION=$(podman --version | cut -d' ' -f3)
    print_status "Podman $PODMAN_VERSION is installed"
    
    # Check if podman is running rootless
    if [ "$EUID" -ne 0 ]; then
        print_status "Running in rootless mode (recommended)"
    else
        print_warning "Running as root - consider using rootless podman"
    fi
else
    print_error "Podman is not installed"
    echo "Installing Podman..."
    sudo dnf install -y podman podman-compose
fi

# Check podman-compose or use docker-compose with podman backend
if command_exists podman-compose; then
    print_status "podman-compose is installed"
    COMPOSE_CMD="podman-compose"
elif command_exists docker-compose; then
    print_status "docker-compose is installed (will use with podman backend)"
    COMPOSE_CMD="docker-compose"
else
    print_warning "podman-compose not found, installing..."
    sudo dnf install -y podman-compose || {
        print_info "Installing via pip..."
        pip3 install --user podman-compose
        export PATH=$PATH:$HOME/.local/bin
    }
    COMPOSE_CMD="podman-compose"
fi

# Setup podman for rootless operation
if [ "$EUID" -ne 0 ]; then
    echo -e "\n🔧 Configuring rootless Podman..."
    
    # Check subuid/subgid
    if ! grep -q "^$USER:" /etc/subuid; then
        print_warning "Setting up subuid/subgid for rootless containers..."
        sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
        print_warning "You may need to logout and login again for changes to take effect"
    fi
    
    # Enable lingering for user systemd services
    loginctl enable-linger $USER 2>/dev/null || true
    
    # Start podman socket
    systemctl --user start podman.socket 2>/dev/null || true
fi

# Check Python
echo -e "\n🐍 Checking Python..."
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_status "Python $PYTHON_VERSION is installed"
else
    print_warning "Python 3 is not installed. Installing..."
    sudo dnf install -y python3 python3-pip python3-devel
fi

# Check Node.js
echo -e "\n📦 Checking Node.js..."
if command_exists node; then
    NODE_VERSION=$(node --version)
    print_status "Node.js $NODE_VERSION is installed"
else
    print_warning "Node.js is not installed. Installing..."
    sudo dnf module enable -y nodejs:18
    sudo dnf install -y nodejs npm
fi

# SELinux context for volumes (Oracle Linux specific)
if command_exists getenforce && [ "$(getenforce)" != "Disabled" ]; then
    print_info "SELinux is enabled, setting contexts for volumes..."
    chcon -Rt svirt_sandbox_file_t backend/ frontend/ nginx/ 2>/dev/null || true
fi

# Create necessary directories
echo -e "\n📁 Creating necessary directories..."
mkdir -p backend/tmp/uploads backend/tmp/exports
mkdir -p nginx/ssl
mkdir -p ~/.config/containers
print_status "Directories created"

# Configure Podman registries for Oracle Linux
if [ ! -f ~/.config/containers/registries.conf ]; then
    echo -e "\n🔧 Configuring Podman registries..."
    cat > ~/.config/containers/registries.conf << 'EOF'
unqualified-search-registries = ["docker.io", "quay.io", "registry.access.redhat.com"]

[[registry]]
location = "docker.io"
insecure = false
EOF
    print_status "Registries configured"
fi

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

# Get WSL IP address
get_wsl_ip() {
    ip addr show eth0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 || \
    hostname -I | awk '{print $1}'
}

WSL_IP=$(get_wsl_ip)
print_status "WSL IP Address: $WSL_IP"

# Check for systemd support in WSL
if [ -d /run/systemd/system ]; then
    print_status "Systemd is available in WSL"
    SYSTEMD_AVAILABLE=true
else
    print_warning "Systemd not available - using direct podman commands"
    SYSTEMD_AVAILABLE=false
fi

# Start services based on argument
START_MODE=${1:-podman}

if [ "$START_MODE" = "podman" ]; then
    echo -e "\n🐳 Starting with Podman Compose..."
    
    # Use podman-compose.yml instead of docker-compose.yml
    export COMPOSE_FILE=podman-compose.yml
    
    # Stop any running containers
    $COMPOSE_CMD down 2>/dev/null || true
    
    # Create pod for better container communication
    podman pod create --name loganalyzer-pod \
        -p 3000:3000 \
        -p 8000:8000 \
        -p 5432:5432 \
        -p 6379:6379 \
        -p 11434:11434 \
        2>/dev/null || true
    
    # Start services
    print_info "Starting services (this may take a while on first run)..."
    $COMPOSE_CMD up -d
    
    # Wait for services to be ready
    echo "Waiting for services to start..."
    sleep 10
    
    # Check service status
    $COMPOSE_CMD ps
    
    print_status "All services started with Podman Compose"
    
elif [ "$START_MODE" = "local" ]; then
    echo -e "\n💻 Starting in local development mode..."
    
    # Install PostgreSQL for Oracle Linux 8
    if ! command_exists psql; then
        print_warning "Installing PostgreSQL..."
        sudo dnf install -y postgresql postgresql-server postgresql-contrib
        sudo postgresql-setup --initdb
        sudo systemctl enable --now postgresql
    fi
    
    # Install Redis for Oracle Linux 8
    if ! command_exists redis-server; then
        print_warning "Installing Redis..."
        sudo dnf module enable -y redis:6
        sudo dnf install -y redis
        sudo systemctl enable --now redis
    fi
    
    # Setup Python virtual environment
    echo "Setting up Python environment..."
    cd backend
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install --upgrade pip
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
fi

# Podman-specific health checks
echo -e "\n🏥 Running health checks..."
if [ "$START_MODE" = "podman" ]; then
    for service in postgres redis backend frontend; do
        if podman ps | grep -q $service; then
            print_status "$service is running"
        else
            print_warning "$service is not running"
        fi
    done
fi

# Display access information
echo -e "\n${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ AI Log Analyzer is ready on Oracle Linux 8!${NC}"
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
echo "🔧 Podman Commands:"
echo "   View logs:     $COMPOSE_CMD logs -f [service]"
echo "   List pods:     podman pod list"
echo "   List containers: podman ps -a"
echo "   Enter container: podman exec -it [container] bash"
echo ""
echo "🛑 To stop all services:"
echo "   ./stop-oracle-wsl.sh"
echo ""

# Oracle Linux specific tips
echo "💡 Oracle Linux 8 Tips:"
echo "   - SELinux: use :Z flag for volumes or 'chcon -t svirt_sandbox_file_t'"
echo "   - Firewall: firewall-cmd --add-port={3000,8000}/tcp --permanent"
echo "   - Systemd: systemctl --user status podman.socket"
echo ""

# Keep script running if in local mode
if [ "$START_MODE" = "local" ]; then
    echo "Press Ctrl+C to stop all services..."
    trap 'kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit' INT
    wait
fi