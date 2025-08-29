# Troubleshooting Guide - AI Log Analyzer

## 🔴 Common Issues and Solutions

### 1. Node.js Error: "Cannot find module 'node:path'"

**Problem**: Old Node.js version (v10 or older) doesn't support `node:` prefix.

**Solution**:
```bash
# Fix Node.js version
./fix-nodejs.sh

# Or manually:
sudo apt-get remove nodejs npm
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. Docker Build Error: "npm ci requires package-lock.json"

**Problem**: Missing `package-lock.json` file.

**Solution**:
```bash
# Generate package-lock.json
cd frontend
npm install
cd ..

# Then rebuild
docker-compose build --no-cache
```

### 3. Out of Disk Space

**Problem**: Docker images taking too much space.

**Solution**:
```bash
# Use the cleanup script
./cleanup.sh

# Or quick cleanup
docker system prune -a --volumes -f

# Check space usage
docker system df
```

### 4. Port Already in Use

**Problem**: Ports 3000, 8000, etc. already in use.

**Solution**:
```bash
# Find what's using the port
sudo lsof -i :3000
sudo lsof -i :8000

# Kill the process
sudo kill -9 $(sudo lsof -t -i:3000)

# Or change ports in docker-compose.yml
```

### 5. Database Connection Failed

**Problem**: Backend can't connect to PostgreSQL.

**Solution**:
```bash
# Reset database
docker-compose down -v
docker-compose up -d postgres
sleep 5
docker-compose up -d

# Check database logs
docker-compose logs postgres
```

### 6. Frontend Not Hot-Reloading

**Problem**: Changes not reflecting in development.

**Solution**:
```bash
# Add to docker-compose.override.yml:
environment:
  - WATCHPACK_POLLING=true
  - CHOKIDAR_USEPOLLING=true

# Restart frontend
docker-compose restart frontend
```

### 7. Permission Denied Errors

**Problem**: Permission issues with files/folders.

**Solution**:
```bash
# Fix permissions
sudo chown -R $USER:$USER .
chmod -R 755 backend frontend

# For Docker socket
sudo usermod -aG docker $USER
# Then logout and login again
```

### 8. Docker Compose Not Found

**Problem**: `docker-compose` command not found.

**Solution**:
```bash
# Install Docker Compose
sudo apt-get update
sudo apt-get install docker-compose

# Or use Docker Compose plugin
docker compose version
# Then use 'docker compose' instead of 'docker-compose'
```

### 9. Redis Connection Error

**Problem**: Redis not connecting or data not persisting.

**Solution**:
```bash
# Check Redis status
docker-compose ps redis
docker-compose logs redis

# Clear Redis cache
docker-compose exec redis redis-cli FLUSHALL

# Restart Redis
docker-compose restart redis
```

### 10. Ollama Model Not Found

**Problem**: AI analysis failing due to missing Ollama model.

**Solution**:
```bash
# Pull model manually
docker-compose exec ollama ollama pull llama3.2

# Or pull smaller model
docker-compose exec ollama ollama pull llama2:7b

# Check available models
docker-compose exec ollama ollama list
```

## 🔍 Debugging Steps

### 1. Check Service Status
```bash
docker-compose ps
```

### 2. View Service Logs
```bash
# All logs
docker-compose logs

# Specific service
docker-compose logs backend
docker-compose logs frontend

# Follow logs
docker-compose logs -f backend
```

### 3. Enter Container for Debugging
```bash
# Backend
docker-compose exec backend bash

# Frontend
docker-compose exec frontend sh

# Database
docker-compose exec postgres psql -U loganalyzer
```

### 4. Check Environment Variables
```bash
docker-compose exec backend env | grep DATABASE
docker-compose exec frontend env | grep NEXT_PUBLIC
```

### 5. Test Service Connectivity
```bash
# From backend to database
docker-compose exec backend ping postgres

# From backend to Redis
docker-compose exec backend ping redis

# Test API
curl http://localhost:8000/docs
curl http://localhost:3000
```

## 🚨 Emergency Reset

If nothing works, perform a complete reset:

```bash
#!/bin/bash
# Complete reset script

# Stop everything
docker-compose down -v --remove-orphans

# Clean Docker
docker system prune -a --volumes -f

# Remove local files
rm -rf frontend/node_modules frontend/.next frontend/package-lock.json
rm -rf backend/__pycache__ backend/venv
rm -rf backend/tmp

# Recreate directories
mkdir -p backend/tmp/uploads backend/tmp/exports

# Reinstall and rebuild
cd frontend && npm install && cd ..
docker-compose build --no-cache
docker-compose up -d
```

## 📊 Performance Issues

### Slow Build Times
```bash
# Use .dockerignore files
# Already configured, but check they exist

# Build specific service
docker-compose build backend

# Use build cache
docker-compose build
```

### High Memory Usage
```bash
# Check memory usage
docker stats

# Limit memory in docker-compose.yml
services:
  backend:
    mem_limit: 1g
```

### Slow File System (WSL)
```bash
# Move project to WSL filesystem
cd ~
git clone [your-repo]

# Don't use /mnt/c/ for better performance
```

## 🔗 Useful Commands Reference

```bash
# Quick status check
docker-compose ps && docker-compose logs --tail=10

# Force rebuild single service
docker-compose up -d --build --force-recreate backend

# Check container health
docker inspect --format='{{.State.Health.Status}}' $(docker-compose ps -q backend)

# Export/Import database
docker-compose exec postgres pg_dump -U loganalyzer loganalyzer > backup.sql
docker-compose exec -T postgres psql -U loganalyzer loganalyzer < backup.sql

# Monitor in real-time
watch -n 2 docker-compose ps
```

## 📞 Getting More Help

1. Check specific service logs: `docker-compose logs [service]`
2. Run in foreground to see all output: `docker-compose up`
3. Check Docker daemon logs: `journalctl -u docker.service`
4. Enable debug mode: `COMPOSE_DEBUG=1 docker-compose up`

## 🎯 Prevention Tips

1. **Regular Cleanup**: Run `./cleanup.sh` weekly
2. **Monitor Space**: Check with `docker system df` regularly
3. **Update Dependencies**: Keep Docker and Node.js updated
4. **Use WSL2**: Better performance than WSL1
5. **Allocate Resources**: Ensure WSL has enough memory (`.wslconfig`)

## 🆘 Still Stuck?

If you're still having issues:

1. Save all logs:
```bash
docker-compose logs > all_logs.txt 2>&1
```

2. Check system info:
```bash
uname -a > system_info.txt
docker version >> system_info.txt
docker-compose version >> system_info.txt
node --version >> system_info.txt
```

3. Try the nuclear reset:
```bash
./cleanup.sh  # Choose option 4
./fix-and-start.sh
```