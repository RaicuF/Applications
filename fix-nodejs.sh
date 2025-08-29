#!/bin/bash

# Fix Node.js version issue in WSL

echo "🔧 Fixing Node.js version issue..."
echo "Current Node version:"
node --version 2>/dev/null || echo "Node not found"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Remove old Node.js versions
echo -e "${YELLOW}Removing old Node.js versions...${NC}"
sudo apt-get remove -y nodejs npm
sudo apt-get autoremove -y

# Clean npm cache
rm -rf ~/.npm

# Install Node.js 18 (LTS)
echo -e "${GREEN}Installing Node.js 18 LTS...${NC}"

# Method 1: Using NodeSource repository (recommended)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
echo -e "\n${GREEN}Verification:${NC}"
echo "Node version: $(node --version)"
echo "NPM version: $(npm --version)"

# Test with a simple script
echo -e "\n${GREEN}Testing Node.js...${NC}"
node -e "console.log('Node.js is working! Path module:', require('path').sep)"

# Install global packages
echo -e "\n${GREEN}Installing useful global packages...${NC}"
sudo npm install -g npm@latest

echo -e "\n${GREEN}✅ Node.js setup complete!${NC}"
echo "You can now run:"
echo "  cd frontend"
echo "  npm install"