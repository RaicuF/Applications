#!/bin/bash

# AI Log Analyzer - WSL Development Helper
# Quick development commands and utilities

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_menu() {
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}   AI Log Analyzer - Development Menu   ${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    echo "1) Start All Services (Docker)"
    echo "2) Start All Services (Local)"
    echo "3) Start All Services (Hybrid)"
    echo "4) Stop All Services"
    echo "5) View Logs (Docker)"
    echo "6) Rebuild Docker Images"
    echo "7) Reset Database"
    echo "8) Run Backend Tests"
    echo "9) Run Frontend Tests"
    echo "10) Install/Update Dependencies"
    echo "11) Check Service Status"
    echo "12) Open in Browser"
    echo "13) Generate Sample Logs"
    echo "14) Backup Database"
    echo "15) Restore Database"
    echo "16) Pull Ollama Model"
    echo "17) Check WSL Resources"
    echo "18) Port Forwarding Setup"
    echo "19) Clean Docker Resources"
    echo "0) Exit"
    echo ""
}

start_docker() {
    echo -e "${GREEN}Starting services with Docker...${NC}"
    ./start-wsl.sh docker
}

start_local() {
    echo -e "${GREEN}Starting services locally...${NC}"
    ./start-wsl.sh local
}

start_hybrid() {
    echo -e "${GREEN}Starting services in hybrid mode...${NC}"
    ./start-wsl.sh hybrid
}

stop_all() {
    echo -e "${YELLOW}Stopping all services...${NC}"
    ./stop-wsl.sh
}

view_logs() {
    echo "Select service to view logs:"
    echo "1) All services"
    echo "2) Backend"
    echo "3) Frontend"
    echo "4) PostgreSQL"
    echo "5) Redis"
    echo "6) Ollama"
    echo "7) Nginx"
    read -p "Choice: " log_choice
    
    case $log_choice in
        1) docker-compose logs -f ;;
        2) docker-compose logs -f backend ;;
        3) docker-compose logs -f frontend ;;
        4) docker-compose logs -f postgres ;;
        5) docker-compose logs -f redis ;;
        6) docker-compose logs -f ollama ;;
        7) docker-compose logs -f nginx ;;
        *) echo "Invalid choice" ;;
    esac
}

rebuild_docker() {
    echo -e "${YELLOW}Rebuilding Docker images...${NC}"
    docker-compose build --no-cache
    echo -e "${GREEN}Images rebuilt successfully${NC}"
}

reset_database() {
    echo -e "${RED}WARNING: This will delete all data!${NC}"
    read -p "Are you sure? (y/N): " confirm
    if [ "$confirm" = "y" ]; then
        docker-compose down -v
        docker-compose up -d postgres
        sleep 5
        echo -e "${GREEN}Database reset complete${NC}"
    fi
}

run_backend_tests() {
    echo -e "${BLUE}Running backend tests...${NC}"
    cd backend
    if [ -d "venv" ]; then
        source venv/bin/activate
    else
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
    fi
    pytest tests/ -v
    cd ..
}

run_frontend_tests() {
    echo -e "${BLUE}Running frontend tests...${NC}"
    cd frontend
    npm test
    cd ..
}

install_dependencies() {
    echo -e "${BLUE}Installing/Updating dependencies...${NC}"
    
    # Backend
    cd backend
    if [ -d "venv" ]; then
        source venv/bin/activate
    else
        python3 -m venv venv
        source venv/bin/activate
    fi
    pip install -r requirements.txt
    cd ..
    
    # Frontend
    cd frontend
    npm install
    cd ..
    
    echo -e "${GREEN}Dependencies updated${NC}"
}

check_status() {
    echo -e "${BLUE}Service Status:${NC}"
    echo ""
    
    # Docker services
    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        echo -e "${GREEN}Docker Services:${NC}"
        docker-compose ps
    else
        echo -e "${YELLOW}No Docker services running${NC}"
    fi
    
    echo ""
    
    # Check ports
    echo -e "${BLUE}Port Status:${NC}"
    for port in 3000 8000 5432 6379 11434; do
        if nc -z localhost $port 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Port $port is open"
        else
            echo -e "${RED}✗${NC} Port $port is closed"
        fi
    done
}

open_browser() {
    WSL_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    echo -e "${BLUE}Opening in browser...${NC}"
    echo "Frontend: http://localhost:3000"
    echo "Backend: http://localhost:8000/docs"
    echo "WSL IP: http://$WSL_IP:3000"
    
    # Try to open in Windows browser
    cmd.exe /c start http://localhost:3000 2>/dev/null || true
}

generate_sample_logs() {
    echo -e "${BLUE}Generating sample log files...${NC}"
    mkdir -p sample_logs
    
    # Generate Apache log
    cat > sample_logs/apache.log << 'EOF'
192.168.1.100 - - [01/Jan/2024:10:15:30 +0000] "GET /index.html HTTP/1.1" 200 1234
192.168.1.101 - admin [01/Jan/2024:10:16:45 +0000] "POST /login HTTP/1.1" 401 567
192.168.1.102 - - [01/Jan/2024:10:17:20 +0000] "GET /admin/users HTTP/1.1" 403 234
10.0.0.50 - - [01/Jan/2024:10:18:15 +0000] "GET /api/data?user=admin' OR '1'='1 HTTP/1.1" 500 789
192.168.1.103 - - [01/Jan/2024:10:19:00 +0000] "GET /../../../etc/passwd HTTP/1.1" 400 123
EOF
    
    # Generate JSON log
    cat > sample_logs/app.json << 'EOF'
{"timestamp":"2024-01-01T10:20:00Z","level":"ERROR","ip":"192.168.1.104","message":"Database connection failed","service":"api"}
{"timestamp":"2024-01-01T10:21:00Z","level":"WARNING","ip":"192.168.1.105","message":"Multiple failed login attempts","service":"auth"}
{"timestamp":"2024-01-01T10:22:00Z","level":"INFO","ip":"192.168.1.106","message":"User logged in successfully","service":"auth"}
EOF
    
    echo -e "${GREEN}Sample logs created in ./sample_logs/${NC}"
}

backup_database() {
    echo -e "${BLUE}Backing up database...${NC}"
    BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
    docker-compose exec -T postgres pg_dump -U loganalyzer loganalyzer > "backups/$BACKUP_FILE"
    echo -e "${GREEN}Backup saved to backups/$BACKUP_FILE${NC}"
}

restore_database() {
    echo "Available backups:"
    ls -la backups/*.sql 2>/dev/null || echo "No backups found"
    read -p "Enter backup filename: " backup_file
    if [ -f "backups/$backup_file" ]; then
        docker-compose exec -T postgres psql -U loganalyzer loganalyzer < "backups/$backup_file"
        echo -e "${GREEN}Database restored from $backup_file${NC}"
    else
        echo -e "${RED}Backup file not found${NC}"
    fi
}

pull_ollama_model() {
    echo -e "${BLUE}Pulling Ollama model...${NC}"
    docker-compose exec ollama ollama pull llama3.2
    echo -e "${GREEN}Model pulled successfully${NC}"
}

check_resources() {
    echo -e "${BLUE}WSL Resource Usage:${NC}"
    echo ""
    echo "Memory:"
    free -h
    echo ""
    echo "Disk:"
    df -h /
    echo ""
    echo "CPU:"
    nproc
    echo ""
    echo "Docker:"
    docker system df
}

setup_port_forwarding() {
    WSL_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    echo -e "${BLUE}Port Forwarding Setup${NC}"
    echo ""
    echo "To access from Windows network:"
    echo ""
    echo "Run these commands in Windows PowerShell (Admin):"
    echo ""
    echo "netsh interface portproxy add v4tov4 listenport=3000 listenaddress=0.0.0.0 connectport=3000 connectaddress=$WSL_IP"
    echo "netsh interface portproxy add v4tov4 listenport=8000 listenaddress=0.0.0.0 connectport=8000 connectaddress=$WSL_IP"
    echo ""
    echo "To remove port forwarding:"
    echo "netsh interface portproxy delete v4tov4 listenport=3000 listenaddress=0.0.0.0"
    echo "netsh interface portproxy delete v4tov4 listenport=8000 listenaddress=0.0.0.0"
    echo ""
    echo "To view current port forwarding:"
    echo "netsh interface portproxy show all"
}

clean_docker() {
    echo -e "${YELLOW}Cleaning Docker resources...${NC}"
    docker system prune -a --volumes
    echo -e "${GREEN}Docker cleanup complete${NC}"
}

# Main loop
while true; do
    print_menu
    read -p "Enter choice: " choice
    
    case $choice in
        1) start_docker ;;
        2) start_local ;;
        3) start_hybrid ;;
        4) stop_all ;;
        5) view_logs ;;
        6) rebuild_docker ;;
        7) reset_database ;;
        8) run_backend_tests ;;
        9) run_frontend_tests ;;
        10) install_dependencies ;;
        11) check_status ;;
        12) open_browser ;;
        13) generate_sample_logs ;;
        14) backup_database ;;
        15) restore_database ;;
        16) pull_ollama_model ;;
        17) check_resources ;;
        18) setup_port_forwarding ;;
        19) clean_docker ;;
        0) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid choice${NC}" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done