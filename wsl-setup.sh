#!/bin/bash

# AI Log Analyzer - WSL Initial Setup Script
# Run this once to set up your WSL environment

set -e

echo "🔧 AI Log Analyzer - WSL Environment Setup"
echo "=========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Detect WSL version and distro
echo -e "\n📍 Detecting WSL environment..."
if grep -qi microsoft /proc/version; then
    print_status "Running in WSL"
    
    # Get distro info
    DISTRO=$(lsb_release -si 2>/dev/null || echo "Unknown")
    DISTRO_VERSION=$(lsb_release -sr 2>/dev/null || echo "Unknown")
    print_info "Distribution: $DISTRO $DISTRO_VERSION"
    
    # Check WSL version
    if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        print_status "WSL 2 detected"
        WSL_VERSION=2
    else
        print_warning "WSL 1 detected - WSL 2 is recommended for better performance"
        WSL_VERSION=1
    fi
else
    print_error "Not running in WSL environment"
    exit 1
fi

# Update system packages
echo -e "\n📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y
print_status "System packages updated"

# Install essential tools
echo -e "\n🛠️ Installing essential tools..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    net-tools \
    htop \
    vim \
    unzip

print_status "Essential tools installed"

# Setup Docker for WSL
echo -e "\n🐳 Setting up Docker..."

# Check if Docker Desktop integration is available
if [ -S /var/run/docker.sock ]; then
    print_status "Docker Desktop integration detected"
    print_info "Using Docker Desktop from Windows"
else
    print_warning "Docker Desktop integration not found"
    echo "Installing Docker in WSL..."
    
    # Remove old Docker installations
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start Docker service
    sudo service docker start
    
    print_status "Docker installed in WSL"
    print_warning "You may need to log out and back in for group changes to take effect"
fi

# Install Docker Compose standalone
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_status "Docker Compose installed"
fi

# Setup Python environment
echo -e "\n🐍 Setting up Python environment..."
sudo apt-get install -y python3 python3-pip python3-venv python3-dev
pip3 install --upgrade pip
print_status "Python environment ready"

# Setup Node.js
echo -e "\n📦 Setting up Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi
print_status "Node.js $(node --version) installed"

# Install PostgreSQL client tools
echo -e "\n🐘 Installing PostgreSQL client tools..."
sudo apt-get install -y postgresql-client
print_status "PostgreSQL client tools installed"

# Install Redis tools
echo -e "\n📮 Installing Redis tools..."
sudo apt-get install -y redis-tools
print_status "Redis tools installed"

# Configure WSL settings
echo -e "\n⚙️ Configuring WSL settings..."

# Create .wslconfig if it doesn't exist
WSLCONFIG_PATH="/mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')/.wslconfig"
if [ ! -f "$WSLCONFIG_PATH" ] && [ "$WSL_VERSION" = "2" ]; then
    print_info "Creating WSL configuration file..."
    cat > /tmp/.wslconfig << EOF
[wsl2]
memory=4GB
processors=2
localhostForwarding=true
EOF
    cp /tmp/.wslconfig "$WSLCONFIG_PATH" 2>/dev/null || print_warning "Could not create .wslconfig"
fi

# Setup Windows Terminal profile (if applicable)
print_info "For better experience, use Windows Terminal with WSL"

# Configure git
echo -e "\n📝 Configuring Git..."
git config --global core.autocrlf input
git config --global core.eol lf
print_status "Git configured for cross-platform development"

# Setup aliases
echo -e "\n🎯 Setting up useful aliases..."
cat >> ~/.bashrc << 'EOF'

# AI Log Analyzer aliases
alias loganalyzer='cd /mnt/c/MyGit/AI_Log_Analyzer'
alias la-start='./start-wsl.sh'
alias la-stop='./stop-wsl.sh'
alias la-logs='docker-compose logs -f'
alias la-status='docker-compose ps'

# Docker aliases
alias dc='docker-compose'
alias dps='docker ps'
alias dexec='docker exec -it'

# WSL specific
alias explorer='explorer.exe .'
alias code='code .'
EOF

print_status "Aliases added to ~/.bashrc"

# Create convenience scripts
echo -e "\n📄 Creating convenience scripts..."

# Create a Windows batch file to start the app
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
WIN_DESKTOP="/mnt/c/Users/$WIN_USER/Desktop"

if [ -d "$WIN_DESKTOP" ]; then
    cat > "$WIN_DESKTOP/Start_LogAnalyzer.bat" << 'EOF'
@echo off
wsl.exe -d Ubuntu bash -c "cd /mnt/c/MyGit/AI_Log_Analyzer && ./start-wsl.sh docker"
pause
EOF
    print_status "Created desktop shortcut: Start_LogAnalyzer.bat"
fi

# Setup Ollama for WSL
echo -e "\n🤖 Setting up Ollama..."
if [ "$WSL_VERSION" = "2" ]; then
    print_info "Ollama will be run in Docker container"
else
    print_warning "WSL 1 detected - Ollama may have limited functionality"
fi

# Make scripts executable
chmod +x start-wsl.sh stop-wsl.sh wsl-setup.sh

# Final system check
echo -e "\n🔍 Running final system check..."

check_command() {
    if command -v $1 &> /dev/null; then
        print_status "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

check_command docker
check_command docker-compose
check_command python3
check_command node
check_command npm
check_command git

# Network information
echo -e "\n🌐 Network Information:"
WSL_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
print_info "WSL IP Address: $WSL_IP"
print_info "Windows can access services at: $WSL_IP"

# Display summary
echo -e "\n${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ WSL Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "📋 Next Steps:"
echo "   1. Reload your shell: source ~/.bashrc"
echo "   2. Navigate to project: cd /mnt/c/MyGit/AI_Log_Analyzer"
echo "   3. Configure environment: cp backend/.env.example backend/.env"
echo "   4. Start the application: ./start-wsl.sh"
echo ""
echo "🚀 Start Options:"
echo "   ./start-wsl.sh docker  - Run everything in Docker (recommended)"
echo "   ./start-wsl.sh local   - Run everything locally"
echo "   ./start-wsl.sh hybrid  - Docker for services, local for app"
echo ""
echo "💡 Tips:"
echo "   - Use 'la-start' alias to quickly start the app"
echo "   - Use 'la-logs' to view Docker logs"
echo "   - Access from Windows at http://$WSL_IP:3000"
echo ""

# Check if reboot is needed
if [ "$WSL_VERSION" = "2" ]; then
    print_warning "If Docker was just installed, you may need to restart WSL:"
    echo "   In PowerShell: wsl --shutdown"
    echo "   Then reopen your WSL terminal"
fi