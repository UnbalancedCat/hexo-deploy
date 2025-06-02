# Hexo Blog Docker Quick Start Guide Hexo Blog Docker 快速启动指南
**Version 版本**: v0.0.3 (Stable 稳定版) | **Status 状态**: 🟢 Production Ready 生产就绪 | **Updated 更新**: 2025-05-30

## 🚀 30-Second Express Launch 30秒极速启动

### 📋 Prerequisites Check 前置检查
```powershell
# Ensure Docker is running 确保Docker运行
docker --version
# Check port availability 检查端口可用性
netstat -ano | findstr ":8080\\|:2222"
```

### ⚡ One-Click Deployment 一键部署
```powershell
# Build and start (copy-paste to execute) 构建并启动 (复制粘贴执行)
docker build -f Dockerfile_v0.0.3 -t hexo-blog:v0.0.3 . && `
docker run -d --name hexo-blog --restart unless-stopped -p 8080:80 -p 2222:22 hexo-blog:v0.0.3 && `
Write-Host "🎉 Deployment complete! Access: http://localhost:8080 部署完成！访问: http://localhost:8080" -ForegroundColor Green
```

### 🌐 Access Now 立即访问
- **Homepage 主页**: http://localhost:8080
- **Health Check 健康检查**: http://localhost:8080/health
- **Status 状态**: `docker ps | findstr hexo-blog`

---

## 🔑 SSH Deployment Configuration (2-Minute Setup) SSH部署配置 (2分钟设置)

### 1. Quick SSH Setup 快速SSH设置
```powershell
# Generate key + Deploy + Test (one command) 生成密钥 + 部署 + 测试 (一条命令)
ssh-keygen -t rsa -b 2048 -f hexo_key -N \'""\' ; `
Start-Sleep 10 ; `
Get-Content hexo_key.pub | docker exec -i hexo-blog bash -c "mkdir -p /home/hexo/.ssh && cat > /home/hexo/.ssh/authorized_keys && chmod 600 /home/hexo/.ssh/authorized_keys && chown -R hexo:hexo /home/hexo/.ssh" ; `
ssh -i hexo_key -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p 2222 hexo@localhost "echo \'✅ SSH configuration successful SSH配置成功\'"
```

### 2. Git Deployment Test Git部署测试
```powershell
# Set Git remote + Push test 设置Git远程 + 推送测试
git remote add docker ssh://hexo@localhost:2222/home/hexo/hexo.git
$env:GIT_SSH_COMMAND = "ssh -i $(Get-Location)\\hexo_key -o StrictHostKeyChecking=no"
# Test deployment 测试部署
echo "# Test deployment 测试部署" > test_deploy.md
git add test_deploy.md && git commit -m "Test Docker deployment 测试Docker部署" && git push docker main
```

---

## 🛠️ Common Commands 常用命令

```powershell
# Status check 状态检查
docker ps | findstr hexo                  # Container status 容器状态
docker logs hexo-blog --tail 10          # Latest logs 最新日志
curl http://localhost:8080/health         # Health check 健康检查

# Management operations 管理操作
docker restart hexo-blog                  # Restart 重启
docker exec -it hexo-blog bash           # Enter container 进入容器
docker stats hexo-blog                   # Resource usage 资源使用

# Quick reset 快速重置
docker stop hexo-blog; docker rm hexo-blog
docker run -d --name hexo-blog -p 8080:80 -p 2222:22 hexo-blog:v0.0.3
```

---

## 🔧 FAQ 常见问题

| Problem 问题 | Solution 解决方案 |
|------|----------|
| **Port in use 端口占用** | `docker run -p 8081:80 -p 2223:22 ...` |
| **SSH failure SSH失败** | `docker exec hexo-blog systemctl restart ssh` |
| **Permission error 权限错误** | `docker exec hexo-blog chown -R hexo:hexo /home/hexo` |
| **Git push failure Git推送失败** | Check SSH key 检查SSH密钥: `ssh -i hexo_key -p 2222 hexo@localhost` |

---

## 📚 Advanced Documentation 进阶文档

- 📖 **Complete Guide 完整指南**: [README_QUICK_START_COMPLETE.md](README_QUICK_START_COMPLETE.md)
- 🏭 **Production Deployment 生产部署**: [doc/summary/PRODUCTION_DEPLOYMENT_GUIDE_v0.0.3.md](doc/summary/PRODUCTION_DEPLOYMENT_GUIDE_v0.0.3.md)
- 🧪 **Test Report 测试报告**: [doc/summary/FINAL_TEST_REPORT_v0.0.3.md](doc/summary/FINAL_TEST_REPORT_v0.0.3.md)

---

## 🎯 Success Verification 成功验证
- ✅ `docker ps` shows `Up (healthy)` `docker ps` 显示 `Up (healthy)`
- ✅ http://localhost:8080 displays webpage http://localhost:8080 显示网页
- ✅ http://localhost:8080/health returns "healthy" http://localhost:8080/health 返回 "healthy"
- ✅ SSH login successful SSH登录成功: `ssh -i hexo_key -p 2222 hexo@localhost`

**Project Status 项目状态**: 🟢 Production Ready 生产就绪 | **Recommended Version 推荐版本**: v0.0.3

---
