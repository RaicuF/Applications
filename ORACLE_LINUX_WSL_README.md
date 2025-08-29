# AI Log Analyzer - Oracle Linux 8 WSL with Podman

## ✅ Compatibility Confirmed

Yes, you can run this application on **Oracle Linux 8 in WSL with Podman**! I've created specific configuration files for your environment.

## 🎯 Oracle Linux 8 + Podman Setup

### System Requirements
- Oracle Linux 8 running in WSL (WSL 1 or WSL 2)
- Podman 4.9.4 (already installed on your system)
- 4GB+ RAM allocated to WSL
- 10GB free disk space

## 🚀 Quick Start

### 1. Initial Setup (Run Once)
```bash
# Make scripts executable
chmod +x setup-oracle-wsl.sh start-oracle-wsl.sh stop-oracle-wsl.sh

# Run the setup script
./setup-oracle-wsl.sh
```

This will:
- Configure Podman for rootless containers
- Install Python 3.9, Node.js 18
- Setup container registries
- Configure SELinux contexts
- Create helpful aliases

### 2. Start the Application
```bash
# Using Podman Compose (Recommended)
./start-oracle-wsl.sh podman

# Or run locally (requires local PostgreSQL/Redis)
./start-oracle-wsl.sh local
```

### 3. Access the Application
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs

## 📁 Oracle Linux Specific Files

- `podman-compose.yml` - Podman-specific compose file with proper image URLs
- `start-oracle-wsl.sh` - Startup script optimized for Oracle Linux 8 + Podman
- `stop-oracle-wsl.sh` - Shutdown script for Podman containers
- `setup-oracle-wsl.sh` - Complete setup script for Oracle Linux 8

## 🔧 Key Differences for Oracle Linux 8

### 1. **Podman Instead of Docker**
- Podman is pre-installed and configured
- Docker commands are aliased to Podman
- Rootless containers by default (more secure)
- No daemon required

### 2. **SELinux Considerations**
The compose file includes `:Z` flags for volumes:
```yaml
volumes:
  - ./backend:/app:Z  # SELinux relabeling
```

### 3. **Container Registries**
Configured to use full image URLs:
```yaml
image: docker.io/library/postgres:15-alpine
```

### 4. **Package Management**
Uses `dnf` instead of `apt`:
```bash
sudo dnf install -y podman podman-compose
```

## 🐳 Podman Commands

### Basic Operations
```bash
# List running containers
podman ps

# List all containers
podman ps -a

# View logs
podman logs -f [container-name]

# Enter container
podman exec -it [container-name] bash

# List pods
podman pod list
```

### Using Podman Compose
```bash
# Start services
podman-compose up -d

# Stop services
podman-compose down

# View logs
podman-compose logs -f [service]

# Rebuild images
podman-compose build --no-cache
```

## 🔒 Security Features

### SELinux
Oracle Linux 8 has SELinux enforcing by default:
```bash
# Check SELinux status
getenforce

# Set context for volumes
chcon -Rt svirt_sandbox_file_t ./backend ./frontend

# Or use :Z flag in compose file (automatic relabeling)
```

### Firewall
If firewall is enabled:
```bash
# Open required ports
sudo firewall-cmd --add-port=3000/tcp --permanent
sudo firewall-cmd --add-port=8000/tcp --permanent
sudo firewall-cmd --reload
```

### Rootless Containers
Podman runs rootless by default:
- More secure than Docker
- No root daemon
- User namespaces for isolation

## 🛠️ Troubleshooting

### Issue: Permission Denied on Volumes
```bash
# Solution 1: Use :Z flag in compose file
volumes:
  - ./data:/data:Z

# Solution 2: Set SELinux context manually
chcon -Rt svirt_sandbox_file_t ./data
```

### Issue: Cannot Find Image
```bash
# Use full registry path
podman pull docker.io/library/nginx:alpine

# Check configured registries
cat ~/.config/containers/registries.conf
```

### Issue: Port Already in Use
```bash
# Find process using port
sudo netstat -tulpn | grep :3000

# Or use ss command
ss -tulpn | grep :3000
```

### Issue: Podman Compose Not Found
```bash
# Install via dnf
sudo dnf install -y podman-compose

# Or install via pip
pip3 install --user podman-compose
export PATH=$PATH:$HOME/.local/bin
```

## 📊 Resource Management

### Check Podman Resources
```bash
# System df
podman system df

# Prune unused resources
podman system prune -af

# Check container stats
podman stats
```

### WSL Memory Configuration
Create/edit `C:\Users\[YourUsername]\.wslconfig`:
```ini
[wsl2]
memory=6GB
processors=4
localhostForwarding=true
```

## 🎯 Aliases (Added by Setup)

```bash
# Application shortcuts
la-start      # Start application
la-stop       # Stop application
la-logs       # View logs
la-status     # Check status

# Podman shortcuts
pd           # podman
pdc          # podman-compose
pdps         # podman ps
pdexec       # podman exec -it
pdclean      # podman system prune -af
```

## 🚦 Service Status Check

```bash
# Check all services
podman-compose ps

# Check specific service
podman ps | grep backend

# Health check
curl http://localhost:8000/health
curl http://localhost:3000
```

## 📝 Development Workflow

1. **Start services:**
   ```bash
   ./start-oracle-wsl.sh podman
   ```

2. **Watch logs:**
   ```bash
   podman-compose logs -f backend frontend
   ```

3. **Make changes:**
   - Backend: Auto-reloads with uvicorn
   - Frontend: Hot-reload with Next.js

4. **Run tests:**
   ```bash
   # Backend tests
   podman-compose exec backend pytest

   # Frontend tests
   podman-compose exec frontend npm test
   ```

5. **Stop services:**
   ```bash
   ./stop-oracle-wsl.sh
   ```

## ✅ Advantages of Podman on Oracle Linux 8

1. **Security**: Rootless containers by default
2. **No Daemon**: No background service required
3. **Docker Compatible**: Can use Docker images and commands
4. **SELinux Integration**: Better security with SELinux
5. **Enterprise Ready**: Oracle Linux is enterprise-grade
6. **Resource Efficient**: Lower overhead than Docker

## 🆘 Getting Help

```bash
# Podman help
podman --help
podman-compose --help

# Check versions
podman version
podman-compose version

# System info
podman info
```

## 🎉 You're All Set!

Your Oracle Linux 8 WSL environment with Podman is fully compatible with this application. The setup scripts handle all Oracle Linux and Podman-specific configurations automatically.