# Hexo Blog Docker Complete Quick Start Guide Hexo Blog 完整快速指南
**Version 版本**: v0.0.3 | **Status 状态**: 🟢 Production Ready 生产就绪 | **Updated 更新**: 2025-05-29

---

## 🚀 5-Minute Quick Deployment 5分钟快速部署

### 📋 Prerequisites 前置要求
- Docker Desktop installed and running Docker Desktop 已安装并运行
- Windows 10/11 + PowerShell 5.0+
- Available ports 可用端口: 8080 (HTTP), 2222 (SSH)

### ⚡ One-Click Start Command 一键启动命令
```powershell
# Build the stable version image 构建稳定版镜像
docker build -f Dockerfile_v0.0.3 -t hexo-blog:v0.0.3 .

# Start the container 启动容器
docker run -d --name hexo-blog --restart unless-stopped \\
  -p 8080:80 -p 2222:22 \\
  hexo-blog:v0.0.3

# Verify status 验证状态
docker ps | findstr hexo-blog
docker logs hexo-blog --tail 10
```

### 🌐 Access Now 立即访问
- **Web Interface Web界面**: http://localhost:8080
- **Health Check 健康检查**: http://localhost:8080/health
- **Status Information 状态信息**: `docker stats hexo-blog`

---

## 🔑 SSH Git Deployment Full Configuration SSH Git 部署完整配置

### 1. Generate and Deploy SSH Keys 生成并部署SSH密钥
```powershell
# Generate key pair (execute in project root directory) 生成密钥对 (在项目根目录执行)
ssh-keygen -t rsa -b 2048 -f hexo_key -N \'""\'

# Wait for the container to fully start (approx. 10-15 seconds) 等待容器完全启动 (约10-15秒)
Start-Sleep -Seconds 15

# Deploy public key to the container 部署公钥到容器
Get-Content hexo_key.pub | docker exec -i hexo-blog bash -c "
mkdir -p /home/hexo/.ssh && 
cat > /home/hexo/.ssh/authorized_keys && 
chmod 600 /home/hexo/.ssh/authorized_keys && 
chmod 700 /home/hexo/.ssh &&
chown -R hexo:hexo /home/hexo/.ssh
"
```

### 2. Verify SSH Connection 验证SSH连接
```powershell
# Test SSH connection 测试SSH连接
ssh -i hexo_key -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p 2222 hexo@localhost "echo \'SSH connection successful ✅ SSH连接成功 ✅\'"
```

### 3. Git Deployment Configuration Git部署配置
```powershell
# Execute in your Hexo blog project 在您的Hexo博客项目中执行
git remote add docker ssh://hexo@localhost:2222/home/hexo/hexo.git

# Set SSH command (Windows) 设置SSH命令 (Windows)
$env:GIT_SSH_COMMAND = "ssh -i $(Get-Location)\\hexo_key -o StrictHostKeyChecking=no"

# Push deployment 推送部署
git add .
git commit -m "Deploy to Docker container 部署到Docker容器"
git push docker main
```

### 4. Verify Deployment Results 验证部署结果
```powershell
# Check deployment logs 检查部署日志
docker exec hexo-blog tail -20 /var/log/container/deployment.log # Updated log path

# Access the updated website 访问更新后的网站
Start-Process "http://localhost:8080"
```

---

## 🛠️ Container Management Commands 容器管理命令

### Basic Operations 基础操作
```powershell
# View all Hexo containers 查看所有Hexo容器
docker ps -a --filter "name=hexo"

# Real-time monitoring 实时监控
docker stats hexo-blog
docker logs -f hexo-blog

# Restart service 重启服务
docker restart hexo-blog

# Enter container for debugging 进入容器调试
docker exec -it hexo-blog bash
```

### Maintenance Operations 维护操作
```powershell
# Completely reset the container 完全重置容器
docker stop hexo-blog; docker rm hexo-blog
docker run -d --name hexo-blog -p 8080:80 -p 2222:22 hexo-blog:v0.0.3

# Clean unused images 清理未使用的镜像
docker image prune -f

# Backup container data (if needed) 备份容器数据 (如果需要)
docker exec hexo-blog tar -czf /tmp/backup.tar.gz /home/hexo /home/www
docker cp hexo-blog:/tmp/backup.tar.gz ./hexo-backup-$(Get-Date -Format "yyyyMMdd-HHmmss").tar.gz
```

---

## 🔧 Troubleshooting Guide 故障排除指南

### Common Issues and Solutions 常见问题解决

#### 1. Port Conflict 端口冲突
```powershell
# Check port usage 检查端口占用
netstat -ano | findstr :8080
netstat -ano | findstr :2222

# Use other ports 使用其他端口
docker run -d --name hexo-blog -p 8081:80 -p 2223:22 hexo-blog:v0.0.3
```

#### 2. SSH Connection Failure SSH连接失败
```powershell
# Check SSH service status 检查SSH服务状态
docker exec hexo-blog systemctl status ssh

# Restart SSH service 重启SSH服务
docker exec hexo-blog systemctl restart ssh

# Check SSH configuration 检查SSH配置
docker exec hexo-blog sshd -T | grep -E "(Port|PermitRootLogin|PubkeyAuthentication)"
```

#### 3. Git Deployment Failure Git部署失败
```powershell
# Check Git repository status 检查Git仓库状态
docker exec hexo-blog ls -la /home/hexo/hexo.git/

# Reinitialize Git repository 重新初始化Git仓库
docker exec hexo-blog bash -c "
cd /home/hexo && 
rm -rf hexo.git && 
git init --bare hexo.git && 
chown -R hexo:hexo hexo.git
"
```

#### 4. Permission Issues 权限问题
```powershell
# Fix file permissions 修复文件权限
docker exec hexo-blog chown -R hexo:hexo /home/hexo /home/www
docker exec hexo-blog chmod -R 755 /home/www
docker exec hexo-blog chmod 600 /home/hexo/.ssh/authorized_keys
```

#### 5. Service Health Check 服务健康检查
```powershell
# Full health check 完整健康检查
docker exec hexo-blog bash -c "
echo \'=== Service Status Check 服务状态检查 ===\' &&
systemctl is-active nginx ssh &&
echo \'=== Port Listening Check 端口监听检查 ===\' &&
ss -tlnp | grep -E \':(80|22)\' &&
echo \'=== File Permission Check 文件权限检查 ===\' &&
ls -la /home/hexo/.ssh/ &&
echo \'=== Disk Space Check 磁盘空间检查 ===\' &&
df -h /
"
```

---

## 📚 Detailed Documentation Index 详细文档索引

| Document 文档 | Purpose 用途 | Status 状态 |
|------|------|------|
| [Production Deployment Guide 生产部署指南](doc/summary/PRODUCTION_DEPLOYMENT_GUIDE_v0.0.3.md) | Production environment deployment 生产环境部署 | ✅ Completed 完成 |
| [Full Test Report 完整测试报告](doc/summary/FINAL_TEST_REPORT_v0.0.3.md) | Functional verification results 功能验证结果 | ✅ Completed 完成 |
| [Project Integrity Check 项目完整性检查](doc/summary/PROJECT_INTEGRITY_CHECK_v0.0.3.md) | Quality assurance 质量保证 | ✅ Completed 完成 |
| [Version Iteration Summary 迭代总结](doc/VERSION_ITERATION_SUMMARY.md) | Complete development history 完整开发历程 | ✅ Completed 完成 |

---

## 🎯 Success Verification Checklist 成功验证清单

### Basic Functionality Test 基础功能测试
- [ ] **Container Start 容器启动**: \`docker ps\` shows \`Up (healthy)\` \`docker ps\` 显示 \`Up (healthy)\`
- [ ] **Web Access Web访问**: http://localhost:8080 returns HTTP 200
- [ ] **Health Check 健康检查**: http://localhost:8080/health returns "healthy"
- [ ] **SSH Connection SSH连接**: \`ssh -i hexo_key -p 2222 hexo@localhost\` logs in successfully
- [ ] **Git Deployment Git部署**: \`git push docker main\` deploys successfully and auto-deploys

### Advanced Functionality Test (v0.0.4-enhanced)
- [ ] **Process Management 进程管理**: \`docker exec hexo-blog supervisorctl status\` shows all services running
- [ ] **Security Hardening 安全加固**: SSH brute force protection is active
- [ ] **Performance Monitoring 性能监控**: \`/status\` endpoint returns detailed status information
- [ ] **Automatic Backup 自动备份**: Backup files are created automatically upon deployment

---

## 🚀 Next Steps 下一步行动

### Immediately Available (v0.0.3-fixed)
1. ✅ Production environment deployment
2. ✅ Blog content publishing
3. ✅ SSH auto-deployment setup

### Planned Testing (v0.0.4-enhanced)
1. 🧪 Functional integrity testing
2. 📊 Performance benchmarking  
3. 🛡️ Security validation
4. 📈 Monitoring system integration

**Recommendation 推荐**: Start with v0.0.3-fixed, consider upgrading to v0.0.4-enhanced after stable operation

---

*Last updated 最后更新: 2025年5月29日 | Project status 项目状态: 生产就绪*
