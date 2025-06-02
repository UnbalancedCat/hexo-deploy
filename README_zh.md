# Hexo Blog Docker 容器化解决方案

**项目状态**: ✅ 生产就绪 | **最新版本**: v0.0.3 (稳定版) | **更新时间**: 2025年5月30日

企业级 Hexo 博客 Docker 容器化解决方案，提供 SSH 访问、Nginx Web 服务、Git 自动部署和全面安全防护。v0.0.3 版本是一个稳定版本，专注于核心功能的可靠性和易用性。

> 📖 **快速开始**: [30秒部署指南](README_QUICK_START_SIMPLE.md)  
> 📖 **完整指南**: [详细部署文档](README_QUICK_START_COMPLETE.md)  
> 📖 **English Documentation**: [README.md](README.md)  
> 📋 **版本历史**: [综合版本总结](doc/COMPREHENSIVE_VERSION_SUMMARY.md)

## 🚀 快速开始

### 即时部署（30秒）
```powershell
# 构建并启动稳定版
docker build -f Dockerfile_v0.0.3 -t hexo-blog:stable . && `
docker run -d --name hexo-blog-stable --restart unless-stopped -p 8080:80 -p 2222:22 hexo-blog:stable && `
Write-Host "🎉 部署完成！访问: http://localhost:8080" -ForegroundColor Green
```

### 访问验证
- 🌐 **Web 界面**: http://localhost:8080  
- 💚 **健康检查**: http://localhost:8080/health  
- 📊 **容器状态**: `docker ps | findstr hexo-blog`

## ✨ 功能特性

### v0.0.3 稳定版特性 ✅  
- 🛡️ **SSH 密钥认证** - 安全远程访问和部署
- 🌐 **Nginx Web 服务** - 高性能静态文件服务  
- 🔄 **Git 自动部署** - 推送即更新的自动化工作流
- 💚 **健康监控** - `/health` 端点实时状态监控
- 🐳 **Docker 优化** - 精简镜像，快速启动
- 📝 **智能日志管理** - 包括日志轮转和大小控制

## 📚 完整文档索引

| 文档类型 | 文件链接 | 用途 | 状态 |
|----------|----------|------|------|
| **快速部署** | [README_QUICK_START_SIMPLE.md](README_QUICK_START_SIMPLE.md) | 30秒部署 | ✅ |
| **完整指南** | [README_QUICK_START_COMPLETE.md](README_QUICK_START_COMPLETE.md) | 详细配置和故障排除 | ✅ |
| **版本总结** | [doc/COMPREHENSIVE_VERSION_SUMMARY.md](doc/COMPREHENSIVE_VERSION_SUMMARY.md) | 完整版本历史和对比 | ✅ |
| **生产部署** | [doc/summary/v0.0.3/](doc/summary/v0.0.3/) | v0.0.3 生产环境部署 | ✅ |
| **测试指南** | [test/v0.0.3/windows/README.md](test/v0.0.3/windows/README.md) | v0.0.3 测试和验证 | ✅ |

## 🧪 测试和验证

### 自动化测试 (v0.0.3)
```powershell
# v0.0.3 稳定版自动化测试
.\test\v0.0.3\windows\run_test.ps1
.\test\v0.0.3\windows\functional_test.ps1
.\test\v0.0.3\windows\log_rotation_test.ps1
.\test\v0.0.3\windows\cleanup_test.ps1

# 测试包括：
# ✅ 容器健康检查
# ✅ Web 服务访问  
# ✅ SSH 密钥认证
# ✅ Git 部署功能
# ✅ 日志轮转功能
```

### 手动验证
```powershell
# v0.0.3 稳定版验证
docker ps | findstr hexo-blog                    # 容器状态
curl http://localhost:8080/health                # 健康检查
ssh -i hexo_key -p 2222 hexo@localhost          # SSH连接
git push docker main                             # Git部署
# 查看部署日志
docker exec hexo-blog-stable cat /var/log/container/deployment.log
```

## 🔧 环境变量配置

### SSH 配置
- `SSH_PORT` - SSH 端口 (默认: 22)
- `PERMIT_ROOT_LOGIN` - 允许 root 登录 (默认: no)
- `PUID` - hexo 用户 ID (默认: 1000)  
- `PGID` - hexo 组 ID (默认: 1000)

### Nginx 配置
- `HTTP_PORT` - HTTP 端口 (默认: 80)
- `NGINX_USER` - Nginx 工作进程用户 (默认: hexo)
- `NGINX_WORKERS` - 工作进程数量 (默认: auto)
- `NGINX_CONNECTIONS` - 工作连接数 (默认: 1024)
- `SERVER_NAME` - 服务器名称 (默认: localhost)
- `WEB_ROOT` - Web 根目录 (默认: /home/www/hexo)

### 系统配置
- `TZ` - 时区 (默认: Asia/Shanghai)

## 📦 部署指南

### 构建镜像
```powershell
# v0.0.3 稳定版构建  
docker build -f Dockerfile_v0.0.3 -t hexo-blog:v0.0.3 .

# 自定义构建参数
docker build -f Dockerfile_v0.0.3 -t hexo-blog:v0.0.3 `
  --build-arg PUID=1001 `
  --build-arg PGID=1001 `
  --build-arg TZ=Asia/Shanghai `
  .

# 查看详细构建过程
docker build -f Dockerfile_v0.0.3 -t hexo-blog:v0.0.3 --progress=plain .
```

### 基础部署
```powershell
# v0.0.3 稳定版 - 简单部署
docker run -d `
  --name hexo-blog-stable `
  -p 2222:22 `
  -p 8080:80 `
  -v ${PWD}\hexo-data:/home/www/hexo `
  -v ${PWD}\ssh-keys:/home/hexo/.ssh `
  -v ${PWD}\container-logs:/var/log/container `
  hexo-blog:v0.0.3
```

### 生产环境部署
```powershell
# v0.0.3 稳定版 - 生产配置
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

### Docker Compose 部署
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

## 🛡️ 安全特性

### v0.0.3 安全特性
- ✅ **SSH 密码认证默认禁用** - 仅支持密钥认证
- ✅ **Root 登录默认禁用** - 最小权限原则
- ✅ **Nginx 非 root 运行** - hexo 用户权限隔离
- ✅ **安全响应头** - CSP, X-Frame-Options, X-Content-Type-Options
- ✅ **服务器标识隐藏** - 减少信息泄露
- ✅ **动态 PUID/PGID** - 文件权限安全

## ⚡ 性能优化

### v0.0.3 性能特性
- 🚀 **Gzip 压缩** - 文本文件智能压缩
- 🚀 **静态文件缓存** - 合理的缓存头设置
- 🚀 **Nginx 性能调优** - sendfile, tcp_nopush, tcp_nodelay
- 🚀 **多阶段构建** - 减少镜像大小

## 📊 监控与日志

### v0.0.3 监控与日志特性
- 📊 **健康检查** - `/health` 端点，30秒间隔检查
- 📝 **智能日志管理** - 彩色输出，10MB大小限制轮转，保留最近5个日志文件
- 📊 **服务监控** - 基础进程状态监控，自动重启
- 🔍 **增强启动日志** - 详细容器启动过程、配置验证和动态权限应用
- 🔄 **定期日志轮转** - 每30分钟自动日志文件轮转检查，带时间戳备份

## 🔗 相关资源

- 📖 **English Documentation**: [README.md](README.md)
- 📋 **完整版本历史**: [综合版本总结](doc/COMPREHENSIVE_VERSION_SUMMARY.md)
- 🚀 **快速部署指南**: [30秒部署](README_QUICK_START_SIMPLE.md)
- 📖 **详细配置指南**: [完整部署文档](README_QUICK_START_COMPLETE.md)
- 🧪 **测试指南**: [test/v0.0.3/windows/README.md](test/v0.0.3/windows/README.md)
- 📊 **技术文档**: [doc/summary/v0.0.3](doc/summary/v0.0.3)

## 🆘 故障排除

### 容器无法启动
```powershell
# 检查容器日志
docker logs hexo-blog-stable

# 检查健康状态 
docker inspect hexo-blog-stable | Select-String Health -A 10

# 检查端口占用
netstat -an | findstr "8080\|2222"
```

### SSH 连接失败
```powershell
# 检查SSH密钥权限 (Windows宿主机)
icacls .\ssh-keys\your_private_key_file # 确保用户有读取权限，且没有不必要的其他权限
# 检查容器内 authorized_keys 权限
docker exec hexo-blog-stable ls -l /home/hexo/.ssh/authorized_keys
docker exec hexo-blog-stable cat /home/hexo/.ssh/authorized_keys # 确认公钥内容正确

# 检查SSH服务状态
docker exec hexo-blog-stable pgrep sshd

# 测试SSH连接
ssh -i .\ssh-keys\your_private_key_file -p 2222 -vvv hexo@localhost
```

### Web服务异常
```powershell
# 检查Nginx状态
docker exec hexo-blog-stable pgrep nginx

# 检查Web服务端点
curl http://localhost:8080/health                  # 健康检查
# 检查Nginx日志
docker exec hexo-blog-stable cat /var/log/nginx/access.log
docker exec hexo-blog-stable cat /var/log/nginx/error.log
```

### Git 部署失败
```powershell
# 检查Git仓库权限
docker exec hexo-blog-stable ls -la /home/hexo/hexo.git/

# 检查部署日志
docker exec hexo-blog-stable cat /var/log/container/deployment.log

# 手动测试Git推送
git push docker main --verbose
```

---

**项目状态**: ✅ 生产就绪  
**维护状态**: 🔄 持续更新  
**技术支持**: 📧 通过 GitHub Issues  
**最后更新**: 2025年5月30日
