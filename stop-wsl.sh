#!/bin/bash

# AI Log Analyzer - WSL Stop Script
# This script stops all running services

set -e

echo "🛑 Stopping AI Log Analyzer services..."
echo "======================================"

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

# Check if Docker containers are running
if docker-compose ps 2>/dev/null | grep -q "Up"; then
    echo "Stopping Docker containers..."
    docker-compose down
    print_status "Docker containers stopped"
else
    print_warning "No Docker containers running"
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

# Kill any remaining Node.js or Python processes related to the app
echo "Checking for remaining processes..."

# Kill uvicorn processes
pkill -f "uvicorn app.main:app" 2>/dev/null && print_status "Killed remaining uvicorn processes" || true

# Kill next dev processes
pkill -f "next dev" 2>/dev/null && print_status "Killed remaining Next.js processes" || true

# Stop local services if running
if systemctl is-system-running &>/dev/null; then
    sudo service postgresql stop 2>/dev/null && print_status "PostgreSQL stopped" || true
    sudo service redis-server stop 2>/dev/null && print_status "Redis stopped" || true
fi

echo ""
print_status "All services stopped successfully"