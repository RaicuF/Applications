#!/bin/bash

# AI Log Analyzer - Docker Cleanup Script
# Helps manage disk space by cleaning up Docker resources

echo "🧹 AI Log Analyzer - Docker Cleanup Tool"
echo "========================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to format bytes
format_bytes() {
    numfmt --to=iec-i --suffix=B "$1"
}

# Show current Docker disk usage
show_usage() {
    echo -e "\n${BLUE}Current Docker Disk Usage:${NC}"
    docker system df
    echo ""
    TOTAL_SIZE=$(docker system df --format "{{.Size}}" | tail -1)
    echo -e "${YELLOW}Total Docker space used: $TOTAL_SIZE${NC}"
}

# Show menu
show_menu() {
    echo -e "\n${GREEN}Select cleanup option:${NC}"
    echo "1) Quick cleanup (stopped containers, dangling images)"
    echo "2) Project cleanup (remove AI Log Analyzer resources)"
    echo "3) Deep cleanup (remove all unused Docker resources)"
    echo "4) Nuclear cleanup (⚠️ REMOVE EVERYTHING)"
    echo "5) Show detailed usage"
    echo "6) Clean build cache only"
    echo "7) Clean volumes only"
    echo "8) Clean old images (>7 days)"
    echo "0) Exit"
    echo ""
}

# Quick cleanup
quick_cleanup() {
    echo -e "\n${YELLOW}Performing quick cleanup...${NC}"
    docker container prune -f
    docker image prune -f
    docker network prune -f
    echo -e "${GREEN}✅ Quick cleanup complete${NC}"
}

# Project cleanup
project_cleanup() {
    echo -e "\n${YELLOW}Removing AI Log Analyzer resources...${NC}"
    
    # Stop project containers
    docker-compose down -v --remove-orphans 2>/dev/null || true
    
    # Remove project images
    echo "Removing project images..."
    docker images | grep -E "(loganalyzer|ai_log_analyzer)" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
    
    # Remove project volumes
    docker volume ls | grep -E "(loganalyzer|ai_log_analyzer)" | awk '{print $2}' | xargs -r docker volume rm -f 2>/dev/null || true
    
    echo -e "${GREEN}✅ Project cleanup complete${NC}"
}

# Deep cleanup
deep_cleanup() {
    echo -e "\n${YELLOW}Performing deep cleanup...${NC}"
    echo "This will remove:"
    echo "- All stopped containers"
    echo "- All unused images"
    echo "- All unused volumes"
    echo "- All unused networks"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker system prune -a --volumes -f
        echo -e "${GREEN}✅ Deep cleanup complete${NC}"
    else
        echo -e "${RED}Cancelled${NC}"
    fi
}

# Nuclear cleanup
nuclear_cleanup() {
    echo -e "\n${RED}⚠️  WARNING: NUCLEAR CLEANUP ⚠️${NC}"
    echo "This will remove:"
    echo "- ALL containers (running and stopped)"
    echo "- ALL images"
    echo "- ALL volumes"
    echo "- ALL networks"
    echo "- ALL build cache"
    echo ""
    echo -e "${RED}This will remove EVERYTHING Docker-related!${NC}"
    read -p "Are you SURE? Type 'yes' to confirm: " confirm
    if [ "$confirm" = "yes" ]; then
        echo -e "${RED}Stopping all containers...${NC}"
        docker stop $(docker ps -aq) 2>/dev/null || true
        
        echo -e "${RED}Removing all containers...${NC}"
        docker rm $(docker ps -aq) 2>/dev/null || true
        
        echo -e "${RED}Removing all images...${NC}"
        docker rmi $(docker images -aq) -f 2>/dev/null || true
        
        echo -e "${RED}Removing all volumes...${NC}"
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        
        echo -e "${RED}Removing all networks...${NC}"
        docker network rm $(docker network ls -q) 2>/dev/null || true
        
        echo -e "${RED}Final system prune...${NC}"
        docker system prune -a --volumes -f
        
        echo -e "${GREEN}✅ Nuclear cleanup complete${NC}"
    else
        echo -e "${GREEN}Cancelled - nothing was removed${NC}"
    fi
}

# Show detailed usage
detailed_usage() {
    echo -e "\n${BLUE}Detailed Docker Usage:${NC}"
    echo ""
    echo "=== IMAGES ==="
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -20
    echo ""
    echo "=== CONTAINERS ==="
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" | head -20
    echo ""
    echo "=== VOLUMES ==="
    docker volume ls
    echo ""
    echo "=== DISK USAGE BY TYPE ==="
    docker system df -v
}

# Clean build cache
clean_cache() {
    echo -e "\n${YELLOW}Cleaning build cache...${NC}"
    docker builder prune -a -f
    echo -e "${GREEN}✅ Build cache cleaned${NC}"
}

# Clean volumes only
clean_volumes() {
    echo -e "\n${YELLOW}Cleaning unused volumes...${NC}"
    docker volume prune -f
    # Also remove anonymous volumes
    docker volume rm $(docker volume ls -qf dangling=true) 2>/dev/null || true
    echo -e "${GREEN}✅ Volumes cleaned${NC}"
}

# Clean old images
clean_old_images() {
    echo -e "\n${YELLOW}Removing images older than 7 days...${NC}"
    docker image prune -a --filter "until=168h" -f
    echo -e "${GREEN}✅ Old images removed${NC}"
}

# Main script
main() {
    show_usage
    
    while true; do
        show_menu
        read -p "Enter choice: " choice
        
        case $choice in
            1) quick_cleanup ;;
            2) project_cleanup ;;
            3) deep_cleanup ;;
            4) nuclear_cleanup ;;
            5) detailed_usage ;;
            6) clean_cache ;;
            7) clean_volumes ;;
            8) clean_old_images ;;
            0) echo "Exiting..."; exit 0 ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
        
        echo ""
        show_usage
    done
}

# Run main function
main