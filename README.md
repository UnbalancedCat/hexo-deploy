# Hexo Blog Docker Containerization Solution

**Project Status**: ✅ Production Ready | **Latest Version**: v0.0.3 (Stable) | **Updated**: May 30, 2025

An enterprise-grade Hexo blog Docker containerization solution providing SSH access, Nginx web service, Git auto-deployment, and comprehensive security protection. Version v0.0.3 is a stable version focusing on core feature reliability and ease of use.

> 📖 **Quick Start**: [30-Second Deployment Guide](README_QUICK_START_SIMPLE.md)  
> 📖 **Complete Guide**: [Detailed Deployment Documentation](README_QUICK_START_COMPLETE.md)  
> 📖 **Chinese Documentation**: [README_zh.md](README_zh.md)  
> 📋 **Version History**: [Comprehensive Version Summary](doc/COMPREHENSIVE_VERSION_SUMMARY.md)

## 🚀 Quick Start

### Instant Deployment (30 seconds)
```powershell
# Build and start stable version
docker build -f Dockerfile_v0.0.3 -t hexo-blog:stable . && `
docker run -d --name hexo-blog-stable --restart unless-stopped -p 8080:80 -p 2222:22 hexo-blog:stable && `
Write-Host "🎉 Deployment Complete! Visit: http://localhost:8080" -ForegroundColor Green
```

### Access Verification
- 🌐 **Web Interface**: http://localhost:8080  
- 💚 **Health Check**: http://localhost:8080/health  
- 📊 **Container Status**: `docker ps | findstr hexo-blog`

## ✨ Core Features

### v0.0.3 Stable Features ✅  
- 🛡️ **SSH Key Authentication** - Secure remote access and deployment
- 🌐 **Nginx Web Service** - High-performance static file serving  
- 🔄 **Git Auto Deployment** - Push-to-update automation workflow
- 💚 **Health Monitoring** - `/health` endpoint real-time status monitoring
- 🐳 **Docker Optimized** - Streamlined image, fast startup
- 📝 **Smart Log Management** - Including log rotation and size control.

## 📚 Complete Documentation Index

| Document Type | File Link | Purpose | Status |
|---------------|-----------|---------|--------|
| **Quick Deploy** | [README_QUICK_START_SIMPLE.md](README_QUICK_START_SIMPLE.md) | 30-second deployment | ✅ |
| **Complete Guide** | [README_QUICK_START_COMPLETE.md](README_QUICK_START_COMPLETE.md) | Detailed configuration and troubleshooting | ✅ |
| **Version Summary** | [doc/COMPREHENSIVE_VERSION_SUMMARY.md](doc/COMPREHENSIVE_VERSION_SUMMARY.md) | Complete version history and comparison | ✅ |
| **Production Deploy** | [doc/summary/v0.0.3/](doc/summary/v0.0.3/) | v0.0.3 production environment deployment | ✅ |
| **Test Guide** | [test/v0.0.3/windows/README.md](test/v0.0.3/windows/README.md) | v0.0.3 testing and verification | ✅ |

## 🧪 Testing and Verification

### Automated Testing (v0.0.3)
```powershell
# v0.0.3 stable version comprehensive testing
cd "test\v0.0.3\windows"
.\run_test.ps1
.\functional_test.ps1
.\log_rotation_test.ps1
.\cleanup_test.ps1

# Testing includes:
# ✅ Container health check
# ✅ Web service functionality      
# ✅ SSH key authentication
# ✅ Git deployment workflow  
# ✅ Log rotation mechanism
```

### Manual Verification
```powershell
# v0.0.3 stable version verification
docker ps | findstr hexo-blog                    # Container status
curl http://localhost:8080/health                # Health check
ssh -i .\ssh-keys\your_private_key_file -p 2222 hexo@localhost # SSH connection (use your key file)
git push docker main                             # Git deployment
# Check deployment log
docker exec hexo-blog-stable cat /var/log/container/deployment.log
```

## 🔧 Environment Variables Configuration

### SSH Configuration
- `SSH_PORT` - SSH port (default: 22)
- `PERMIT_ROOT_LOGIN` - Allow root login (default: no)
- `PUID` - hexo user ID (default: 1000)  
- `PGID` - hexo group ID (default: 1000)

### Nginx Configuration
- `HTTP_PORT` - HTTP port (default: 80)
- `NGINX_USER` - Nginx worker process user (default: hexo)
- `NGINX_WORKERS` - Number of worker processes (default: auto)
- `NGINX_CONNECTIONS` - Worker connections (default: 1024)
- `SERVER_NAME` - Server name (default: localhost)
- `WEB_ROOT` - Web root directory (default: /home/www/hexo)

### System Configuration
- `TZ` - Timezone (default: Asia/Shanghai)

## 📦 Deployment Guide

### Build Images
```powershell
# v0.0.3 stable version build  
docker build -f Dockerfile_v0.0.3 -t hexo-blog:v0.0.3 .

# Custom build arguments
docker build -f Dockerfile_v0.0.3 -t hexo-blog:v0.0.3 `
  --build-arg PUID=1001 `
  --build-arg PGID=1001 `
  --build-arg TZ=Asia/Shanghai `
  .

# View detailed build process
docker build -f Dockerfile_v0.0.3 -t hexo-blog:v0.0.3 --progress=plain .
```

### Basic Deployment
```powershell
# v0.0.3 stable version - simple deployment
docker run -d `
  --name hexo-blog-stable `
  -p 2222:22 `
  -p 8080:80 `
  -v ${PWD}\hexo-data:/home/www/hexo `
  -v ${PWD}\ssh-keys:/home/hexo/.ssh `
  -v ${PWD}\container-logs:/var/log/container `
  hexo-blog:v0.0.3
```

### Production Environment Deployment
```powershell
# v0.0.3 stable version - production configuration
docker run -d `
  --name hexo-blog-prod `
  --restart unless-stopped `
  -p 2222:22 `
  -p 8080:80 `
  -e SSH_PORT=22 `
  -e HTTP_PORT=80 `
  -e PUID=1001 `
  -e PGID=1001 `
  -e SERVER_NAME=yourdomain.com `
  -e NGINX_WORKERS=auto `
  -e NGINX_CONNECTIONS=1024 `
  -v ${PWD}\hexo-data:/home/www/hexo `
  -v ${PWD}\ssh-keys:/home/hexo/.ssh `
  -v ${PWD}\container-logs:/var/log/container `
  -v ${PWD}\nginx-logs:/var/log/nginx `
  hexo-blog:v0.0.3
```

### Docker Compose Deployment
```yaml
version: '3.8'
services:
  hexo-blog:
    build:
      context: .
      dockerfile: Dockerfile_v0.0.3
      args:
        - PUID=1001
        - PGID=1001
        - TZ=Asia/Shanghai
    container_name: hexo-blog-stable
    restart: unless-stopped
    ports:
      - "2222:22"
      - "8080:80"
    environment:
      - PUID=1001
      - PGID=1001
      - SERVER_NAME=yourdomain.com
      - NGINX_WORKERS=auto
      - NGINX_CONNECTIONS=1024
      - TZ=Asia/Shanghai
    volumes:
      - ./hexo-data:/home/www/hexo
      - ./ssh-keys:/home/hexo/.ssh
      - ./git-repo:/home/hexo/hexo.git
      - ./logs/container:/var/log/container
      - ./logs/nginx:/var/log/nginx
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
```

## 🛡️ Security Features

### v0.0.3 Security Features
- ✅ **SSH Password Authentication Disabled** - Key-based authentication only
- ✅ **Root Login Disabled** - Principle of least privilege
- ✅ **Nginx Non-root Execution** - hexo user privilege isolation
- ✅ **Security Response Headers** - CSP, X-Frame-Options, X-Content-Type-Options
- ✅ **Server Identity Hidden** - Reduced information disclosure
- ✅ **Dynamic PUID/PGID** - File permission security

## ⚡ Performance Optimization

### v0.0.3 Performance Features
- 🚀 **Gzip Compression** - Smart compression for text files
- 🚀 **Static File Caching** - Reasonable cache header settings
- 🚀 **Nginx Performance Tuning** - sendfile, tcp_nopush, tcp_nodelay
- 🚀 **Multi-stage Build** - Reduced image size

## 📊 Monitoring & Logging

### v0.0.3 Monitoring & Logging Features
- 📊 **Health Check** - `/health` endpoint, 30-second interval checks
- 📝 **Smart Log Management** - Colored output, 10MB size limit rotation, keeps last 5 log files.
- 📊 **Service Monitoring** - Basic process status monitoring, auto-restart
- 🔍 **Enhanced startup logs**: Detailed container startup process, configuration validation, and dynamic permission application
- 🔄 **Periodic log rotation**: Automatic log file rotation checks every 30 minutes with timestamped backups

## Git Deployment

The container includes a bare Git repository for easy deployment:

```bash
# On your local machine, add the container as a remote
# Replace your-server with your server's IP or hostname, and 2222 with the mapped SSH port
git remote add deploy ssh://hexo@your-server:2222/home/hexo/hexo.git

# Deploy your Hexo site (ensure your SSH key is added to the agent or specified)
git push deploy main
```

The post-receive hook will automatically checkout files to `/home/www/hexo`, set proper permissions, and log detailed deployment information including file counts and total size to `/var/log/container/deployment.log`.

## Volumes

| Volume Path in Container | Description | Purpose |
|--------------------------|-------------|---------|
| `/home/www/hexo`         | Hexo site files | Static website content |
| `/home/hexo/.ssh`        | SSH keys and configuration | SSH authentication (mount your `authorized_keys`) |
| `/home/hexo/hexo.git`    | Git repository for deployment | Automated deployment (managed by container) |
| `/var/log/container`     | Container service logs | Application logging (e.g., `deployment.log`) |
| `/var/log/nginx`         | Nginx access and error logs | Web server logging |

## Port Mapping

| Container Port | Host Port (Example) | Protocol | Description |
|----------------|---------------------|----------|-------------|
| 22             | 2222                | TCP      | SSH server |
| 80             | 8080                | TCP      | HTTP web server |

## Troubleshooting

### Container won't start
```powershell
# Check container logs
docker logs hexo-blog-stable # Or your container name

# Check health status
docker inspect hexo-blog-stable | Select-String Health -A 10

# Check for port conflicts on the host
netstat -an | findstr "8080" # Check for your HTTP port
netstat -an | findstr "2222" # Check for your SSH port
```

### SSH connection issues
```powershell
# Verify SSH key permissions on your local machine (PowerShell example)
# Ensure your private key file (e.g., id_rsa) is protected
icacls .\ssh-keys\your_private_key_file # Should typically only grant access to your user

# Check authorized_keys in the container
docker exec hexo-blog-stable ls -la /home/hexo/.ssh/
docker exec hexo-blog-stable cat /home/hexo/.ssh/authorized_keys # Verify your public key is present and correct

# Check SSH service status in container
docker exec hexo-blog-stable ps aux | grep sshd

# Verbose SSH connection test from your local machine
ssh -i .\ssh-keys\your_private_key_file -p 2222 -vvv hexo@localhost
```

### Nginx issues / Web service not accessible
```powershell
# Test Nginx configuration in container
docker exec hexo-blog-stable nginx -t

# Check Nginx logs in container
docker exec hexo-blog-stable tail -f /var/log/nginx/error.log
docker exec hexo-blog-stable tail -f /var/log/nginx/access.log

# Check Nginx status in container
docker exec hexo-blog-stable ps aux | grep nginx

# Test health endpoint
curl http://localhost:8080/health
```

### Git Deployment Failures
```powershell
# Check permissions of the bare repository in the container
docker exec hexo-blog-stable ls -la /home/hexo/hexo.git/

# Check the deployment log in the container
docker exec hexo-blog-stable cat /var/log/container/deployment.log

# Test Git push with verbosity
git push deploy main -vvv
```

## Version Information

### v0.0.3 (Current Stable)
- ✅ **Smart Log Size Control**: Implemented and tested log rotation for `deployment.log` (1MB limit, keeps 5 backups).
- ✅ **SSH Stability**: Resolved SSH login failures by correcting `authorized_keys` permissions within the container post-startup.
- ✅ **Test Suite Enhancements**: Updated and validated `run_test.ps1` and `functional_test.ps1` for v0.0.3.
- ✅ **Documentation**: Updated README files to reflect v0.0.3 as the latest stable version.
- Focus on stability and core functionality.

### v0.0.2
- Enhanced security with advanced headers (CSP, Referrer-Policy)
- Intelligent log rotation with 10MB file size limit (initial implementation)
- Dynamic PUID/PGID support for proper file ownership
- Dedicated `/health` endpoint for enhanced monitoring
- Improved SSH security (MaxAuthTries, ClientAlive settings)
- Heredoc syntax for better script readability
- Minimal production image (removed vim, nodejs, npm)
- Enhanced deployment logging with detailed file tracking
- Advanced service monitoring with automatic recovery
- Smart configuration template rendering

### v0.0.1
- Implemented multi-stage Docker build
- Integrated SSH and Nginx services
- Template-based configuration system
- Colored logging output
- Automatic service monitoring and restart
- Health check functionality
- Git automated deployment support
- Security hardening configuration

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/YourFeature`)
3. Make your changes
4. Test the Docker build (`docker build -f Dockerfile_v0.0.3 -t hexo-blog:test .`)
5. Commit your changes (`git commit -m 'Add some feature'`)
6. Push to the branch (`git push origin feature/YourFeature`)
7. Submit a pull request

## File Structure

```
dockerfiledir/
├── Dockerfile_v0.0.3          # Current stable Dockerfile
├── Dockerfile_v0.0.4          # Previous development Dockerfile (archived)
├── README.md                  # This file (English documentation)
├── README_zh.md               # Chinese documentation
├── README_QUICK_START_SIMPLE.md
├── README_QUICK_START_COMPLETE.md
├── start.sh                   # Main entrypoint script for the container
├── arch/                      # Archived Dockerfiles (v0.0.1, v0.0.2)
├── doc/                       # Additional documentation
│   ├── COMPREHENSIVE_VERSION_SUMMARY.md
│   └── ...
└── test/
    └── v0.0.3/
        └── windows/             # Test scripts for v0.0.3
            ├── run_test.ps1
            ├── functional_test.ps1
            ├── log_rotation_test.ps1
            ├── cleanup_test.ps1
            └── README.md        # Test guide for v0.0.3
```

## License

This project is open source and available under the [MIT License](LICENSE).

## 🔗 Related Resources

- 📖 **Chinese Documentation**: [README_zh.md](README_zh.md)
- 📋 **Complete Version History**: [Comprehensive Version Summary](doc/COMPREHENSIVE_VERSION_SUMMARY.md)
- 🚀 **Quick Deployment Guide**: [30-Second Deployment](README_QUICK_START_SIMPLE.md)
- 📖 **Detailed Configuration Guide**: [Complete Deployment Documentation](README_QUICK_START_COMPLETE.md)
- 🧪 **Test Guide (v0.0.3)**: [test/v0.0.3/windows/README.md](test/v0.0.3/windows/README.md)
- 📊 **Technical Documentation (v0.0.3)**: [doc/summary/v0.0.3](doc/summary/v0.0.3)

---

**Project Status**: ✅ Production Ready  
**Maintenance Status**: 🔄 Actively Maintained  
**Technical Support**: 📧 Via GitHub Issues  
**Last Updated**: May 30, 2025
