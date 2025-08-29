#!/bin/bash

# AI Log Analyzer - Oracle Linux 8 WSL Setup Script
# Complete setup for Oracle Linux 8 with Podman in WSL

set -e

echo "🔧 AI Log Analyzer - Oracle Linux 8 WSL Setup"
echo "============================================="

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

# Check Oracle Linux
echo -e "\n📍 Verifying Oracle Linux 8 environment..."
if [ -f /etc/oracle-release ]; then
    ORACLE_VERSION=$(cat /etc/oracle-release)
    print_status "Running on $ORACLE_VERSION"
elif grep -q "Oracle Linux" /etc/os-release; then
    ORACLE_VERSION=$(grep VERSION /etc/os-release | head -1 | cut -d'"' -f2)
    print_status "Oracle Linux $ORACLE_VERSION detected"
else
    print_error "This script is designed for Oracle Linux 8"
    exit 1
fi

# Check WSL
if grep -qi microsoft /proc/version; then
    print_status "Running in WSL environment"
    
    # Check WSL version
    if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        print_status "WSL 2 detected (recommended)"
        WSL_VERSION=2
    else
        print_warning "WSL 1 detected - WSL 2 is recommended for better performance"
        WSL_VERSION=1
    fi
else
    print_warning "Not in WSL environment, continuing anyway..."
fi

# Enable EPEL repository
echo -e "\n📦 Enabling repositories..."
sudo dnf install -y oracle-epel-release-el8
sudo dnf config-manager --set-enabled ol8_developer_EPEL
print_status "EPEL repository enabled"

# Update system
echo -e "\n📦 Updating system packages..."
sudo dnf update -y
print_status "System updated"

# Install essential tools
echo -e "\n🛠️ Installing essential tools..."
sudo dnf install -y \
    git \
    curl \
    wget \
    make \
    gcc \
    gcc-c++ \
    kernel-devel \
    vim \
    nano \
    htop \
    net-tools \
    bind-utils \
    tar \
    unzip \
    jq \
    tmux

print_status "Essential tools installed"

# Install and configure Podman
echo -e "\n🐳 Installing Podman and container tools..."
sudo dnf module enable -y container-tools:ol8
sudo dnf install -y \
    podman \
    podman-compose \
    buildah \
    skopeo \
    containers-common \
    fuse-overlayfs \
    slirp4netns

print_status "Podman $(podman --version | cut -d' ' -f3) installed"

# Configure Podman for rootless operation
echo -e "\n🔧 Configuring rootless Podman..."

# Setup subuid/subgid for rootless containers
if ! grep -q "^$USER:" /etc/subuid; then
    sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
    print_status "Configured subuid/subgid for rootless containers"
    print_warning "You may need to logout and login for changes to take effect"
fi

# Create Podman configuration directories
mkdir -p ~/.config/containers
mkdir -p ~/.local/share/containers/storage

# Configure storage for better performance in WSL
cat > ~/.config/containers/storage.conf << 'EOF'
[storage]
driver = "overlay"
runroot = "/run/user/$UID"
graphroot = "$HOME/.local/share/containers/storage"

[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
EOF
print_status "Configured Podman storage for WSL"

# Configure registries
cat > ~/.config/containers/registries.conf << 'EOF'
unqualified-search-registries = ["docker.io", "quay.io", "registry.access.redhat.com", "registry.fedoraproject.org"]

[[registry]]
location = "docker.io"
insecure = false

[[registry.mirror]]
location = "mirror.gcr.io"
EOF
print_status "Configured container registries"

# Install Python 3.11 (Oracle Linux 8 comes with 3.6, we need newer)
echo -e "\n🐍 Installing Python 3.11..."
if ! command -v python3.11 &> /dev/null; then
    sudo dnf module enable -y python39
    sudo dnf install -y python39 python39-pip python39-devel
    sudo alternatives --set python3 /usr/bin/python3.9
    print_status "Python 3.9 installed (3.11 not available in OL8 repos)"
else
    print_status "Python 3.11 already installed"
fi

# Create Python virtual environment wrapper
cat >> ~/.bashrc << 'EOF'

# Python virtual environment helper
mkvenv() {
    python3 -m venv ${1:-venv}
    source ${1:-venv}/bin/activate
    pip install --upgrade pip
}
EOF

# Install Node.js 18
echo -e "\n📦 Installing Node.js 18..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo dnf install -y nodejs
else
    NODE_VERSION=$(node --version)
    print_status "Node.js $NODE_VERSION already installed"
fi

# Install PostgreSQL client tools
echo -e "\n🐘 Installing PostgreSQL client tools..."
sudo dnf install -y postgresql

# Install Redis client tools
echo -e "\n📮 Installing Redis client tools..."
sudo dnf module enable -y redis:6
sudo dnf install -y redis

# Setup Docker compatibility alias
echo -e "\n🔗 Setting up Docker compatibility..."
if ! command -v docker &> /dev/null; then
    sudo ln -s /usr/bin/podman /usr/bin/docker
    print_status "Created docker -> podman symlink"
fi

# Configure firewall (if enabled)
if systemctl is-active --quiet firewalld; then
    echo -e "\n🔥 Configuring firewall..."
    sudo firewall-cmd --permanent --add-port=3000/tcp
    sudo firewall-cmd --permanent --add-port=8000/tcp
    sudo firewall-cmd --permanent --add-port=5432/tcp
    sudo firewall-cmd --permanent --add-port=6379/tcp
    sudo firewall-cmd --permanent --add-port=11434/tcp
    sudo firewall-cmd --reload
    print_status "Firewall configured"
fi

# Configure SELinux contexts
if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
    echo -e "\n🔒 Configuring SELinux..."
    # Set proper context for Podman
    sudo setsebool -P container_manage_cgroup on
    print_status "SELinux configured for containers"
fi

# Setup WSL-specific configurations
if [ -n "$WSL_VERSION" ]; then
    echo -e "\n⚙️ Configuring WSL-specific settings..."
    
    # WSL 2 memory configuration
    if [ "$WSL_VERSION" = "2" ]; then
        WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
        WSLCONFIG_PATH="/mnt/c/Users/$WIN_USER/.wslconfig"
        
        if [ ! -f "$WSLCONFIG_PATH" ]; then
            print_info "Creating WSL configuration..."
            cat > /tmp/.wslconfig << EOF
[wsl2]
memory=6GB
processors=4
localhostForwarding=true
kernelCommandLine = cgroup_enable=1 cgroup_memory=1
EOF
            cp /tmp/.wslconfig "$WSLCONFIG_PATH" 2>/dev/null || print_warning "Could not create .wslconfig"
        fi
    fi
fi

# Create helpful aliases
echo -e "\n🎯 Setting up aliases..."
cat >> ~/.bashrc << 'EOF'

# AI Log Analyzer aliases
alias loganalyzer='cd /mnt/c/MyGit/AI_Log_Analyzer'
alias la-start='./start-oracle-wsl.sh'
alias la-stop='./stop-oracle-wsl.sh'
alias la-logs='podman-compose logs -f'
alias la-status='podman-compose ps'

# Podman aliases
alias pd='podman'
alias pdc='podman-compose'
alias pdps='podman ps'
alias pdpsa='podman ps -a'
alias pdimg='podman images'
alias pdexec='podman exec -it'
alias pdlogs='podman logs -f'
alias pdpod='podman pod'
alias pdclean='podman system prune -af'

# Development aliases
alias py='python3'
alias vact='source venv/bin/activate'
alias npmr='npm run'

# WSL specific
alias explorer='explorer.exe .'
alias code='code .'
alias winip="ip route | grep default | awk '{print \$3}'"
EOF

print_status "Aliases configured"

# Install podman-compose via pip if not available
if ! command -v podman-compose &> /dev/null; then
    echo -e "\n📦 Installing podman-compose via pip..."
    pip3 install --user podman-compose
    export PATH=$PATH:$HOME/.local/bin
    echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
    print_status "podman-compose installed"
fi

# Create convenience scripts
echo -e "\n📄 Creating convenience scripts..."

# Quick test script
cat > test-podman.sh << 'EOF'
#!/bin/bash
echo "Testing Podman installation..."
podman run --rm hello-world
echo ""
echo "Podman info:"
podman info --format json | jq '.host.os, .host.arch, .host.kernel'
EOF
chmod +x test-podman.sh

# Make all scripts executable
chmod +x start-oracle-wsl.sh stop-oracle-wsl.sh setup-oracle-wsl.sh test-podman.sh

# Test Podman
echo -e "\n🧪 Testing Podman..."
podman run --rm docker.io/library/hello-world &> /dev/null && print_status "Podman test successful" || print_warning "Podman test failed"

# Get network information
echo -e "\n🌐 Network Information:"
WSL_IP=$(ip addr show eth0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 || hostname -I | awk '{print $1}')
print_info "WSL IP Address: $WSL_IP"

# Final checks
echo -e "\n🔍 Running final system check..."

check_command() {
    if command -v $1 &> /dev/null; then
        VERSION=$($1 --version 2>/dev/null | head -1)
        print_status "$1: $VERSION"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

check_command podman
check_command podman-compose
check_command python3
check_command node
check_command npm
check_command git

# Display summary
echo -e "\n${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Oracle Linux 8 WSL Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "📋 Next Steps:"
echo "   1. Reload shell: source ~/.bashrc"
echo "   2. Test Podman: ./test-podman.sh"
echo "   3. Navigate to project: cd /mnt/c/MyGit/AI_Log_Analyzer"
echo "   4. Configure environment: cp backend/.env.example backend/.env"
echo "   5. Start application: ./start-oracle-wsl.sh"
echo ""
echo "🚀 Start Options:"
echo "   ./start-oracle-wsl.sh podman  - Run with Podman Compose (recommended)"
echo "   ./start-oracle-wsl.sh local   - Run everything locally"
echo ""
echo "🔧 Podman Tips:"
echo "   - Use 'podman' instead of 'docker' (or use alias)"
echo "   - Rootless containers are configured by default"
echo "   - Use ':Z' flag for SELinux volume mounts"
echo "   - Check pods: podman pod list"
echo ""
echo "💡 Oracle Linux 8 Specific:"
echo "   - SELinux is enforcing by default"
echo "   - Firewall rules have been configured"
echo "   - Python 3.9 is installed (latest available in OL8)"
echo ""

if [ "$WSL_VERSION" = "2" ]; then
    print_warning "If this is a fresh setup, restart WSL for all changes to take effect:"
    echo "   In PowerShell: wsl --shutdown"
    echo "   Then reopen your WSL terminal"
fi