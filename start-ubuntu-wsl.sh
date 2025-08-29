#!/bin/bash

# AI Log Analyzer - Ubuntu WSL2 Startup Script
# Simple startup for Ubuntu WSL2 with Docker

set -e

echo "🚀 AI Log Analyzer - Ubuntu WSL2 Startup"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running!"
    echo "Please start Docker Desktop or Docker daemon"
    echo "For Docker Desktop: Make sure it's running on Windows"
    echo "For native Docker: sudo service docker start"
    exit 1
fi

print_status "Docker is running"

# Check docker-compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    print_error "Docker Compose not found!"
    echo "Install with: sudo apt-get install docker-compose"
    exit 1
fi

print_status "Using: $COMPOSE_CMD"

# Create necessary directories
mkdir -p backend/tmp/uploads backend/tmp/exports nginx/ssl
print_status "Directories created"

# Setup environment files
if [ ! -f backend/.env ]; then
    if [ -f backend/.env.example ]; then
        cp backend/.env.example backend/.env
        print_warning "Created backend/.env - Please update with your API keys"
    else
        cat > backend/.env << EOF
DATABASE_URL=postgresql+asyncpg://loganalyzer:securepassword123@postgres/loganalyzer
REDIS_URL=redis://redis:6379
SECRET_KEY=your-secret-key-change-in-production-$(openssl rand -hex 32)
VIRUSTOTAL_API_KEY=
ABUSEIPDB_API_KEY=
EOF
        print_warning "Created backend/.env with defaults"
    fi
fi

if [ ! -f frontend/.env.local ]; then
    echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > frontend/.env.local
    print_status "Created frontend/.env.local"
fi

# Get WSL IP
WSL_IP=$(hostname -I | awk '{print $1}')
print_status "WSL IP: $WSL_IP"

# Build and start services
echo -e "\n🐳 Starting Docker services..."

# Stop any running containers
$COMPOSE_CMD down 2>/dev/null || true

# Build images
echo "Building Docker images..."
$COMPOSE_CMD build

# Start services
echo "Starting services..."
$COMPOSE_CMD up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check service status
echo -e "\n📊 Service Status:"
$COMPOSE_CMD ps

# Check if services are healthy
check_service() {
    if $COMPOSE_CMD ps | grep -q "$1.*Up"; then
        print_status "$1 is running"
        return 0
    else
        print_error "$1 is not running"
        return 1
    fi
}

echo -e "\n🏥 Health Check:"
check_service "postgres"
check_service "redis"
check_service "backend"
check_service "frontend"

# Display access information
echo -e "\n${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ AI Log Analyzer is ready!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo "📌 Access URLs:"
echo "   Frontend:  http://localhost:3000"
echo "   Backend:   http://localhost:8000"
echo "   API Docs:  http://localhost:8000/docs"
echo ""
echo "🌐 From Windows Browser:"
echo "   Frontend:  http://$WSL_IP:3000"
echo "   Backend:   http://$WSL_IP:8000"
echo ""
echo "📝 Commands:"
echo "   View logs:    $COMPOSE_CMD logs -f [service]"
echo "   Stop all:     $COMPOSE_CMD down"
echo "   Restart:      $COMPOSE_CMD restart [service]"
echo "   Shell:        $COMPOSE_CMD exec [service] bash"
echo ""
echo "🛑 To stop all services:"
echo "   ./stop-ubuntu-wsl.sh or $COMPOSE_CMD down"
echo ""

# Show logs for any failed services
if ! check_service "backend" &>/dev/null; then
    echo -e "\n${YELLOW}Backend logs:${NC}"
    $COMPOSE_CMD logs --tail=20 backend
fi

if ! check_service "frontend" &>/dev/null; then
    echo -e "\n${YELLOW}Frontend logs:${NC}"
    $COMPOSE_CMD logs --tail=20 frontend
fi