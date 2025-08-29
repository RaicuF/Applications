# Docker Commands Guide - AI Log Analyzer

## 🧹 Docker Cleanup Commands

### Space Management - Clean Up Everything

```bash
# ⚠️ NUCLEAR OPTION - Removes EVERYTHING (containers, images, volumes, networks)
docker system prune -a --volumes -f

# More selective cleanup:
# Remove all stopped containers
docker container prune -f

# Remove all unused images
docker image prune -a -f

# Remove all unused volumes
docker volume prune -f

# Remove all unused networks
docker network prune -f
```

### Remove Specific Project Resources

```bash
# Stop and remove all project containers and volumes
docker-compose down -v

# Remove all project images
docker-compose down --rmi all

# Remove everything including orphan containers
docker-compose down -v --remove-orphans --rmi all

# Remove specific images by name
docker images | grep loganalyzer | awk '{print $3}' | xargs docker rmi -f
```

### Check Disk Usage

```bash
# See how much space Docker is using
docker system df

# Detailed breakdown
docker system df -v

# List all images with size
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# List containers with size
docker ps -a --size
```

## 🚀 Common Docker Compose Commands

### Building and Starting

```bash
# Build without cache (fresh build)
docker-compose build --no-cache

# Build specific service
docker-compose build backend

# Start all services
docker-compose up -d

# Start and rebuild
docker-compose up -d --build

# Start with logs
docker-compose up

# Start specific service
docker-compose up -d backend
```

### Stopping and Removing

```bash
# Stop all services
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop, remove containers, images, and volumes
docker-compose down -v --rmi all

# Remove only local images (not pulled from registry)
docker-compose down --rmi local
```

### Viewing Logs and Status

```bash
# View all logs
docker-compose logs

# Follow logs (real-time)
docker-compose logs -f

# View specific service logs
docker-compose logs backend
docker-compose logs -f frontend

# Last 100 lines only
docker-compose logs --tail=100

# Check service status
docker-compose ps

# Check service health
docker-compose ps --services --filter "status=running"
```

### Executing Commands

```bash
# Enter a container
docker-compose exec backend bash
docker-compose exec frontend sh

# Run command in container
docker-compose exec backend python -m pytest
docker-compose exec frontend npm test

# Run command in new container
docker-compose run --rm backend python manage.py migrate
```

## 🔄 Development Workflow Commands

### Quick Restart

```bash
# Restart specific service
docker-compose restart backend

# Restart all services
docker-compose restart

# Rebuild and restart specific service
docker-compose up -d --build backend
```

### Database Operations

```bash
# Reset database (remove volume)
docker-compose down -v
docker-compose up -d postgres

# Backup database
docker-compose exec postgres pg_dump -U loganalyzer loganalyzer > backup.sql

# Restore database
docker-compose exec -T postgres psql -U loganalyzer loganalyzer < backup.sql

# Access database shell
docker-compose exec postgres psql -U loganalyzer -d loganalyzer
```

### Redis Operations

```bash
# Access Redis CLI
docker-compose exec redis redis-cli

# Clear Redis cache
docker-compose exec redis redis-cli FLUSHALL

# Check Redis memory
docker-compose exec redis redis-cli INFO memory
```

## 🔍 Debugging Commands

### Container Inspection

```bash
# Inspect container details
docker-compose exec backend env
docker inspect $(docker-compose ps -q backend)

# Check container resource usage
docker stats $(docker-compose ps -q)

# Check container processes
docker-compose top
```

### Network Debugging

```bash
# List networks
docker network ls

# Inspect network
docker network inspect ai_log_analyzer_loganalyzer-network

# Test connectivity between containers
docker-compose exec backend ping postgres
docker-compose exec backend curl http://frontend:3000
```

## 💾 Space-Saving Tips

### 1. Use Multi-Stage Builds
Already implemented in Dockerfiles to reduce image size.

### 2. Regular Cleanup Script
Create `cleanup.sh`:
```bash
#!/bin/bash
echo "🧹 Cleaning Docker resources..."

# Stop all containers
docker-compose down

# Remove unused images older than 24h
docker image prune -a --filter "until=24h" -f

# Remove unused volumes
docker volume prune -f

# Show space saved
docker system df
```

### 3. Limit Log Size
Add to `docker-compose.yml`:
```yaml
services:
  backend:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## 🚨 Emergency Commands

### When Everything is Broken

```bash
# Complete reset
docker-compose down -v --remove-orphans
docker system prune -a --volumes -f
rm -rf frontend/node_modules frontend/.next
rm -rf backend/__pycache__ backend/venv
docker-compose build --no-cache
docker-compose up -d
```

### Port Conflicts

```bash
# Find what's using a port
sudo lsof -i :3000
sudo lsof -i :8000

# Kill process using port
sudo kill -9 $(sudo lsof -t -i:3000)
```

### Permission Issues

```bash
# Fix permissions
sudo chown -R $USER:$USER .
chmod -R 755 backend frontend
```

## 📊 Monitoring Commands

### Real-time Monitoring

```bash
# Watch container stats
watch docker-compose ps

# Monitor logs
docker-compose logs -f --tail=50

# Monitor specific service
docker-compose logs -f backend | grep ERROR
```

### Resource Usage

```bash
# Check total Docker disk usage
du -sh /var/lib/docker/

# Check image sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | sort -k3 -h

# Find large containers
docker ps -a --size --format "table {{.Names}}\t{{.Size}}"
```

## 🔧 Maintenance Schedule

### Daily
```bash
# Check service health
docker-compose ps
```

### Weekly
```bash
# Clean stopped containers and unused images
docker system prune -f
```

### Monthly
```bash
# Full cleanup (be careful!)
docker system prune -a --volumes -f
# Rebuild images
docker-compose build --no-cache
```

## 🎯 Quick Reference Aliases

Add to `~/.bashrc`:
```bash
# Docker Compose aliases
alias dc='docker-compose'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'
alias dclogs='docker-compose logs -f'
alias dcps='docker-compose ps'
alias dcrestart='docker-compose restart'
alias dcbuild='docker-compose build'
alias dcexec='docker-compose exec'

# Docker cleanup aliases
alias dclean='docker system prune -f'
alias dcleanall='docker system prune -a --volumes -f'
alias dclear='docker-compose down -v --rmi all --remove-orphans'

# Project specific
alias loganalyzer-reset='docker-compose down -v && docker-compose up -d --build'
alias loganalyzer-logs='docker-compose logs -f backend frontend'
alias loganalyzer-clean='docker-compose down -v --rmi all && docker system prune -f'
```

## 📝 Notes

- Always use `-v` flag with `down` to remove volumes if you want a fresh database
- Use `--no-cache` with `build` to ensure fresh builds
- Add `-f` flag to skip confirmation prompts
- Use `docker-compose` for project-specific commands
- Use `docker` for system-wide commands
- Regular cleanup prevents disk space issues

## 🆘 Troubleshooting Checklist

1. **Service won't start**: Check logs with `docker-compose logs [service]`
2. **Out of space**: Run `docker system prune -a --volumes -f`
3. **Port conflict**: Check with `lsof -i :[port]`
4. **Slow builds**: Use `.dockerignore` file, clean Docker cache
5. **Can't connect**: Check network with `docker network ls`
6. **Database issues**: Reset with `docker-compose down -v`