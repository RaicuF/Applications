#!/bin/bash

# AI Log Analyzer - Management Script
# Professional management tool for production deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_NAME="AI Log Analyzer"
COMPOSE_CMD=""

# Detect docker-compose command
detect_compose() {
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        # Default to docker-compose and let it fail if not installed
        COMPOSE_CMD="docker-compose"
    fi
}

# Fix line endings (Windows/WSL issue)
fix_line_endings() {
    echo "Fixing file permissions..."
    find . -type f -name "*.sh" -exec sed -i 's/\r$//' {} \;
    find . -type f -name "*.sh" -exec chmod +x {} \;
    find . -type f -name "*.yml" -exec sed -i 's/\r$//' {} \;
    find . -type f -name "Dockerfile*" -exec sed -i 's/\r$//' {} \;
}

# Start services
start_services() {
    echo -e "${GREEN}Starting $PROJECT_NAME...${NC}"
    
    # Create required directories
    mkdir -p backend/tmp/uploads backend/tmp/exports nginx/ssl
    
    # Setup environment files if missing
    if [ ! -f backend/.env ]; then
        cp backend/.env.example backend/.env 2>/dev/null || \
        cat > backend/.env << EOF
DATABASE_URL=postgresql+asyncpg://loganalyzer:securepassword123@postgres/loganalyzer
REDIS_URL=redis://redis:6379
SECRET_KEY=$(openssl rand -hex 32)
VIRUSTOTAL_API_KEY=
ABUSEIPDB_API_KEY=
EOF
        echo -e "${YELLOW}Created backend/.env - Please add your API keys${NC}"
    fi
    
    if [ ! -f frontend/.env.local ]; then
        echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > frontend/.env.local
    fi
    
    # Build and start
    $COMPOSE_CMD build
    $COMPOSE_CMD up -d
    
    echo -e "${GREEN}Services started successfully${NC}"
    echo "Frontend: http://localhost:3000"
    echo "Backend API: http://localhost:8000/docs"
}

# Stop services
stop_services() {
    echo -e "${YELLOW}Stopping services...${NC}"
    $COMPOSE_CMD down
    echo -e "${GREEN}Services stopped${NC}"
}

# Clean Docker resources
clean_docker() {
    echo -e "${YELLOW}Cleaning Docker resources...${NC}"
    
    case "$1" in
        soft)
            docker system prune -f
            echo -e "${GREEN}Soft cleanup complete${NC}"
            ;;
        hard)
            $COMPOSE_CMD down -v
            docker system prune -a -f
            echo -e "${GREEN}Hard cleanup complete${NC}"
            ;;
        full)
            $COMPOSE_CMD down -v --rmi all
            docker system prune -a --volumes -f
            echo -e "${GREEN}Full cleanup complete${NC}"
            ;;
        *)
            echo "Usage: $0 clean [soft|hard|full]"
            ;;
    esac
    
    docker system df
}

# View logs
view_logs() {
    if [ -z "$1" ]; then
        $COMPOSE_CMD logs -f
    else
        $COMPOSE_CMD logs -f "$1"
    fi
}

# Check status
check_status() {
    echo -e "${BLUE}Service Status:${NC}"
    $COMPOSE_CMD ps
    echo ""
    echo -e "${BLUE}Docker Disk Usage:${NC}"
    docker system df
}

# Rebuild services
rebuild_services() {
    echo -e "${YELLOW}Rebuilding services...${NC}"
    $COMPOSE_CMD down
    $COMPOSE_CMD build --no-cache
    $COMPOSE_CMD up -d
    echo -e "${GREEN}Rebuild complete${NC}"
}

# Fix Node.js (for local development)
fix_nodejs() {
    echo -e "${YELLOW}Fixing Node.js installation...${NC}"
    
    # Remove old Node.js
    sudo apt-get remove -y nodejs npm 2>/dev/null || true
    
    # Install Node.js 18
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    echo -e "${GREEN}Node.js $(node --version) installed${NC}"
}

# Backup database
backup_database() {
    BACKUP_DIR="backups"
    mkdir -p $BACKUP_DIR
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.sql"
    
    echo -e "${BLUE}Creating database backup...${NC}"
    $COMPOSE_CMD exec -T postgres pg_dump -U loganalyzer loganalyzer > "$BACKUP_FILE"
    echo -e "${GREEN}Backup saved to $BACKUP_FILE${NC}"
}

# Restore database
restore_database() {
    if [ -z "$1" ]; then
        echo "Usage: $0 restore <backup_file>"
        echo "Available backups:"
        ls -la backups/*.sql 2>/dev/null || echo "No backups found"
        return 1
    fi
    
    if [ -f "$1" ]; then
        echo -e "${YELLOW}Restoring database from $1...${NC}"
        $COMPOSE_CMD exec -T postgres psql -U loganalyzer loganalyzer < "$1"
        echo -e "${GREEN}Database restored${NC}"
    else
        echo -e "${RED}Backup file not found: $1${NC}"
        return 1
    fi
}

# Show help
show_help() {
    echo -e "${BLUE}$PROJECT_NAME - Management Script${NC}"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start              Start all services"
    echo "  stop               Stop all services"
    echo "  restart            Restart all services"
    echo "  status             Show service status"
    echo "  logs [service]     View logs (optional: specific service)"
    echo "  rebuild            Rebuild and restart all services"
    echo "  clean [soft|hard|full]  Clean Docker resources"
    echo "  backup             Backup database"
    echo "  restore <file>     Restore database from backup"
    echo "  fix-node           Fix Node.js installation"
    echo "  fix-lines          Fix line endings (Windows/WSL)"
    echo "  help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start           # Start the application"
    echo "  $0 logs backend    # View backend logs"
    echo "  $0 clean full      # Complete cleanup"
    echo "  $0 backup          # Create database backup"
}

# Main execution
detect_compose
fix_line_endings

case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        start_services
        ;;
    status)
        check_status
        ;;
    logs)
        view_logs "$2"
        ;;
    rebuild)
        rebuild_services
        ;;
    clean)
        clean_docker "$2"
        ;;
    backup)
        backup_database
        ;;
    restore)
        restore_database "$2"
        ;;
    fix-node)
        fix_nodejs
        ;;
    fix-lines)
        fix_line_endings
        echo -e "${GREEN}Line endings fixed${NC}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac