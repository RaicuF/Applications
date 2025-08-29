#!/bin/bash

# Quick fix and start script for Ubuntu WSL2

echo "🔧 Fixing common issues and starting AI Log Analyzer..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create necessary directories
echo "Creating directories..."
mkdir -p backend/tmp/uploads backend/tmp/exports nginx/ssl
mkdir -p backend/app/services backend/app/utils

# Fix permissions
echo "Fixing permissions..."
chmod -R 755 backend frontend
chmod +x *.sh

# Generate package-lock.json if missing
if [ ! -f frontend/package-lock.json ]; then
    echo -e "${YELLOW}Generating package-lock.json...${NC}"
    cd frontend
    npm install
    cd ..
fi

# Create .env files if missing
if [ ! -f backend/.env ]; then
    echo -e "${YELLOW}Creating backend/.env...${NC}"
    cat > backend/.env << EOF
DATABASE_URL=postgresql+asyncpg://loganalyzer:securepassword123@postgres/loganalyzer
REDIS_URL=redis://redis:6379
SECRET_KEY=your-secret-key-$(openssl rand -hex 16)
VIRUSTOTAL_API_KEY=
ABUSEIPDB_API_KEY=
EOF
fi

if [ ! -f frontend/.env.local ]; then
    echo "Creating frontend/.env.local..."
    echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > frontend/.env.local
fi

# Clean Docker environment
echo "Cleaning Docker environment..."
docker-compose down -v 2>/dev/null || true
docker system prune -f

# Build and start
echo -e "${GREEN}Building and starting services...${NC}"
docker-compose build --no-cache
docker-compose up -d

# Wait for services
echo "Waiting for services to start..."
sleep 15

# Check status
echo -e "\n${GREEN}Service Status:${NC}"
docker-compose ps

# Show URLs
WSL_IP=$(hostname -I | awk '{print $1}')
echo -e "\n${GREEN}✅ Application should be available at:${NC}"
echo "   Local: http://localhost:3000"
echo "   WSL IP: http://$WSL_IP:3000"
echo ""
echo "If there are issues, check logs with:"
echo "   docker-compose logs backend"
echo "   docker-compose logs frontend"