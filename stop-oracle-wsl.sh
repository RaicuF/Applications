#!/bin/bash

# AI Log Analyzer - Oracle Linux WSL Stop Script
# Stops all services running under Podman

set -e

echo "🛑 Stopping AI Log Analyzer services on Oracle Linux..."
echo "====================================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Detect compose command
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    print_warning "No compose command found, using podman directly"
    COMPOSE_CMD=""
fi

# Stop Podman Compose services
if [ -n "$COMPOSE_CMD" ]; then
    if [ -f podman-compose.yml ]; then
        export COMPOSE_FILE=podman-compose.yml
    fi
    
    echo "Stopping Podman Compose services..."
    $COMPOSE_CMD down 2>/dev/null && print_status "Compose services stopped" || print_warning "No compose services running"
fi

# Stop individual Podman containers
echo "Checking for individual Podman containers..."
for container in loganalyzer-postgres loganalyzer-redis loganalyzer-backend loganalyzer-frontend loganalyzer-ollama loganalyzer-nginx; do
    if podman ps -a | grep -q $container; then
        podman stop $container 2>/dev/null && print_status "Stopped $container" || true
        podman rm $container 2>/dev/null && print_status "Removed $container" || true
    fi
done

# Stop and remove pods
echo "Checking for Podman pods..."
if podman pod exists loganalyzer-pod 2>/dev/null; then
    podman pod stop loganalyzer-pod 2>/dev/null && print_status "Stopped loganalyzer-pod" || true
    podman pod rm loganalyzer-pod 2>/dev/null && print_status "Removed loganalyzer-pod" || true
fi

# Check for local development PIDs
if [ -f .backend.pid ]; then
    BACKEND_PID=$(cat .backend.pid)
    if kill -0 $BACKEND_PID 2>/dev/null; then
        kill $BACKEND_PID
        print_status "Backend process stopped (PID: $BACKEND_PID)"
    else
        print_warning "Backend process not found (PID: $BACKEND_PID)"
    fi
    rm .backend.pid
fi

if [ -f .frontend.pid ]; then
    FRONTEND_PID=$(cat .frontend.pid)
    if kill -0 $FRONTEND_PID 2>/dev/null; then
        kill $FRONTEND_PID
        print_status "Frontend process stopped (PID: $FRONTEND_PID)"
    else
        print_warning "Frontend process not found (PID: $FRONTEND_PID)"
    fi
    rm .frontend.pid
fi

# Kill any remaining processes
echo "Checking for remaining processes..."
pkill -f "uvicorn app.main:app" 2>/dev/null && print_status "Killed remaining uvicorn processes" || true
pkill -f "next dev" 2>/dev/null && print_status "Killed remaining Next.js processes" || true

# Stop local services if running (Oracle Linux specific)
if systemctl is-active --quiet postgresql; then
    sudo systemctl stop postgresql && print_status "PostgreSQL stopped" || true
fi

if systemctl is-active --quiet redis; then
    sudo systemctl stop redis && print_status "Redis stopped" || true
fi

# Clean up Podman resources (optional)
read -p "Clean up unused Podman resources? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleaning up Podman resources..."
    podman system prune -f && print_status "Cleaned unused containers and images"
fi

echo ""
print_status "All services stopped successfully"

# Show remaining Podman resources
echo ""
echo "📊 Remaining Podman resources:"
echo "Pods: $(podman pod list --quiet | wc -l)"
echo "Containers: $(podman ps -a --quiet | wc -l)"
echo "Images: $(podman images --quiet | wc -l)"
echo "Volumes: $(podman volume list --quiet | wc -l)"