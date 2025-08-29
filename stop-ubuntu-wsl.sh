#!/bin/bash

# AI Log Analyzer - Ubuntu WSL2 Stop Script

echo "🛑 Stopping AI Log Analyzer services..."

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

# Detect docker-compose command
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "Docker Compose not found!"
    exit 1
fi

# Stop all services
$COMPOSE_CMD down

echo -e "${GREEN}✓${NC} All services stopped"