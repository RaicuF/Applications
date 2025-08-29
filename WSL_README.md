# AI Log Analyzer - WSL Setup Guide

## 🚀 Quick Start for WSL Users

This guide helps you run the AI Log Analyzer in Windows Subsystem for Linux (WSL).

## Prerequisites

- Windows 10/11 with WSL 2 installed (WSL 1 works but WSL 2 is recommended)
- Ubuntu/Debian WSL distribution
- At least 8GB RAM allocated to WSL
- 10GB free disk space

## Initial Setup

### 1. First-time Setup
Run the setup script to install all dependencies:
```bash
./wsl-setup.sh
```
This will install Docker, Python, Node.js, and all required tools.

### 2. Reload Shell
After setup, reload your shell configuration:
```bash
source ~/.bashrc
```

## Starting the Application

### Option 1: Docker Mode (Recommended)
Run everything in Docker containers:
```bash
./start-wsl.sh docker
```

### Option 2: Local Development Mode
Run everything locally (requires local PostgreSQL and Redis):
```bash
./start-wsl.sh local
```

### Option 3: Hybrid Mode
Docker for databases, local for application:
```bash
./start-wsl.sh hybrid
```

## Accessing the Application

### From WSL/Linux:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Documentation: http://localhost:8000/docs

### From Windows Browser:
The script will display your WSL IP address. Access using:
- Frontend: http://[WSL-IP]:3000
- Backend API: http://[WSL-IP]:8000

### Finding WSL IP:
```bash
ip addr show eth0 | grep inet
```

## Development Menu

For an interactive development menu:
```bash
./wsl-dev.sh
```

Features:
- Start/stop services
- View logs
- Run tests
- Database management
- Port forwarding setup
- Resource monitoring

## Useful Commands

### Quick Aliases (added to ~/.bashrc):
```bash
la-start    # Start the application
la-stop     # Stop the application
la-logs     # View Docker logs
la-status   # Check service status
```

### Docker Commands:
```bash
# View running containers
docker-compose ps

# View logs
docker-compose logs -f [service]

# Restart a service
docker-compose restart [service]

# Execute commands in container
docker-compose exec backend bash
```

## Troubleshooting

### Docker Issues

#### Docker daemon not running:
```bash
# If using Docker Desktop
# Make sure Docker Desktop is running on Windows

# If using native Docker in WSL
sudo service docker start
```

#### Permission denied:
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Network Issues

#### Can't access from Windows:
1. Check WSL IP address:
```bash
ip addr show eth0
```

2. Check Windows Firewall:
```powershell
# In Windows PowerShell (Admin)
New-NetFirewallRule -DisplayName "WSL" -Direction Inbound -InterfaceAlias "vEthernet (WSL)" -Action Allow
```

3. Setup port forwarding (optional):
```powershell
# In Windows PowerShell (Admin)
netsh interface portproxy add v4tov4 listenport=3000 listenaddress=0.0.0.0 connectport=3000 connectaddress=[WSL-IP]
```

### Memory Issues

#### WSL using too much memory:
Create/edit `C:\Users\[YourUsername]\.wslconfig`:
```ini
[wsl2]
memory=4GB
processors=2
```
Then restart WSL:
```powershell
wsl --shutdown
```

### Database Connection Issues

#### Reset database:
```bash
docker-compose down -v
docker-compose up -d postgres
```

## Performance Tips

### WSL 2 Optimization

1. **Store project files in WSL filesystem** (not /mnt/c/):
```bash
# Better performance
cd ~/projects/AI_Log_Analyzer

# Slower (Windows filesystem)
cd /mnt/c/MyGit/AI_Log_Analyzer
```

2. **Allocate sufficient resources** in `.wslconfig`:
```ini
[wsl2]
memory=8GB
processors=4
swap=4GB
```

3. **Use Docker Desktop integration** for better performance

### Development Tips

1. **Use VS Code with WSL extension**:
```bash
code .  # Opens VS Code connected to WSL
```

2. **Terminal recommendations**:
   - Windows Terminal
   - Configure with Ubuntu/WSL profile
   - Enable GPU acceleration

3. **File watching issues**:
If hot-reload doesn't work, increase watchers:
```bash
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Stopping Services

To stop all services:
```bash
./stop-wsl.sh
```

## Cleaning Up

### Remove Docker volumes and images:
```bash
docker-compose down -v
docker system prune -a
```

### Remove project dependencies:
```bash
rm -rf backend/venv
rm -rf frontend/node_modules
```

## Additional Resources

- [WSL Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [Docker Desktop WSL Integration](https://docs.docker.com/desktop/windows/wsl/)
- [VS Code WSL Extension](https://code.visualstudio.com/docs/remote/wsl)

## Support

For WSL-specific issues:
1. Check this guide first
2. Run `./wsl-dev.sh` and use option 17 to check resources
3. Review Docker and application logs
4. Ensure all prerequisites are installed

## Quick Troubleshooting Checklist

- [ ] WSL 2 installed and running
- [ ] Docker Desktop or Docker in WSL running
- [ ] Sufficient memory allocated (4GB minimum)
- [ ] All scripts are executable (`chmod +x *.sh`)
- [ ] Environment files configured (`.env` files)
- [ ] No port conflicts (3000, 8000, 5432, 6379)
- [ ] Windows Firewall not blocking connections