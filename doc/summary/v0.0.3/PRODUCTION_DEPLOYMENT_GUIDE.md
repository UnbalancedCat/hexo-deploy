# Hexo Blog Docker 生产部署指南
**版本**: v0.0.3-fixed  
**更新日期**: 2025年5月29日  
**状态**: 生产就绪 ✅

## 📋 概述

此指南提供了完整的Hexo Blog Docker容器生产部署流程。容器已通过全面测试，包含所有必要的安全配置、性能优化和故障恢复机制。

## 🚀 快速部署

### 步骤1: 构建生产镜像
```bash
# 克隆或下载项目文件
cd /path/to/dockerfiledir

# 构建生产镜像 (使用修复版Dockerfile)
docker build -f Dockerfile_v0.0.3-fixed -t hexo-blog:v0.0.3-fixed .

# 验证镜像构建成功
docker images | grep hexo-blog
```

### 步骤2: 启动生产容器
```bash
# 生产环境启动 (自定义端口)
docker run -d \
  --name hexo-blog-prod \
  --restart unless-stopped \
  -p 80:80 \
  -p 2022:22 \
  -v hexo-data:/home/www/hexo \
  -v hexo-git:/home/hexo/hexo.git \
  -v hexo-logs:/var/log/container \
  hexo-blog:v0.0.3-fixed

# 检查容器状态
docker ps -a | grep hexo-blog-prod
docker logs hexo-blog-prod
```

### 步骤3: 配置SSH密钥访问
```bash
# 生成生产环境SSH密钥对
ssh-keygen -t ed25519 -f ~/.ssh/hexo_blog_prod -C "hexo-blog-production"

# 部署公钥到容器
cat ~/.ssh/hexo_blog_prod.pub | docker exec -i hexo-blog-prod bash -c "
  mkdir -p /home/hexo/.ssh && 
  cat > /home/hexo/.ssh/authorized_keys && 
  chmod 600 /home/hexo/.ssh/authorized_keys && 
  chown -R hexo:hexo /home/hexo/.ssh
"

# 测试SSH连接
ssh -i ~/.ssh/hexo_blog_prod -p 2022 hexo@YOUR_SERVER_IP "echo 'SSH连接成功'"
```

### 步骤4: 配置Git部署
```bash
# 在本地博客项目中添加生产环境Git远程仓库
cd /path/to/your/hexo/blog
git remote add production ssh://hexo@YOUR_SERVER_IP:2022/home/hexo/hexo.git

# 配置SSH客户端使用正确的密钥
echo "Host YOUR_SERVER_IP
    Port 2022
    User hexo
    IdentityFile ~/.ssh/hexo_blog_prod
    StrictHostKeyChecking no" >> ~/.ssh/config

# 部署博客内容
git push production main  # 或 master 分支
```

## 🔧 生产环境配置

### 反向代理配置 (推荐)

#### Nginx反向代理
```nginx
# /etc/nginx/sites-available/hexo-blog
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    
    location / {
        proxy_pass http://localhost;  # 如果容器绑定80端口
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 健康检查
    location /health {
        proxy_pass http://localhost/health;
        access_log off;
    }
}
```

#### Apache反向代理
```apache
<VirtualHost *:80>
    ServerName yourdomain.com
    ServerAlias www.yourdomain.com
    
    ProxyPreserveHost On
    ProxyPass /health http://localhost/health
    ProxyPass / http://localhost/
    ProxyPassReverse / http://localhost/
    
    # 日志配置
    ErrorLog ${APACHE_LOG_DIR}/hexo-blog_error.log
    CustomLog ${APACHE_LOG_DIR}/hexo-blog_access.log combined
</VirtualHost>
```

### SSL/TLS 配置

#### 使用Let's Encrypt
```bash
# 安装Certbot
sudo apt-get update
sudo apt-get install certbot python3-certbot-nginx

# 获取SSL证书
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# 设置自动续期
sudo crontab -e
# 添加: 0 12 * * * /usr/bin/certbot renew --quiet
```

### 防火墙配置
```bash
# UFW防火墙配置示例
sudo ufw allow 22/tcp        # SSH
sudo ufw allow 80/tcp        # HTTP
sudo ufw allow 443/tcp       # HTTPS
sudo ufw allow 2022/tcp      # Hexo Blog SSH (生产)
sudo ufw enable
```

## 📊 监控与日志

### 容器监控
```bash
# 创建监控脚本
cat > /usr/local/bin/hexo-monitor.sh << 'EOF'
#!/bin/bash
CONTAINER_NAME="hexo-blog-prod"

# 检查容器健康状态
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME 2>/dev/null)
if [ "$HEALTH" != "healthy" ]; then
    echo "[$(date)] 警告: 容器健康检查失败 - $HEALTH"
    # 发送告警通知 (可集成邮件、Slack等)
fi

# 检查磁盘使用
DISK_USAGE=$(df /var/lib/docker | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "[$(date)] 警告: 磁盘使用率过高 - ${DISK_USAGE}%"
fi
EOF

chmod +x /usr/local/bin/hexo-monitor.sh

# 添加到定时任务
echo "*/5 * * * * /usr/local/bin/hexo-monitor.sh >> /var/log/hexo-monitor.log 2>&1" | crontab -
```

### 日志轮转配置
```bash
# 创建logrotate配置
sudo tee /etc/logrotate.d/hexo-blog << 'EOF'
/var/log/container/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 644 root root
    postrotate
        docker kill -s USR1 hexo-blog-prod
    endscript
}
EOF
```

### Prometheus监控 (可选)
```yaml
# docker-compose.monitoring.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
```

## 🔄 备份与恢复

### 自动备份脚本
```bash
#!/bin/bash
# /usr/local/bin/hexo-backup.sh

BACKUP_DIR="/backup/hexo-blog"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="hexo-blog-prod"

mkdir -p $BACKUP_DIR

# 备份Git仓库
docker exec $CONTAINER_NAME tar -czf - -C /home/hexo hexo.git > \
    $BACKUP_DIR/hexo-git-$DATE.tar.gz

# 备份Web内容
docker exec $CONTAINER_NAME tar -czf - -C /home/www hexo > \
    $BACKUP_DIR/hexo-www-$DATE.tar.gz

# 备份配置文件
docker exec $CONTAINER_NAME tar -czf - -C /etc/container templates > \
    $BACKUP_DIR/hexo-config-$DATE.tar.gz

# 保留最近30天的备份
find $BACKUP_DIR -name "hexo-*-*.tar.gz" -mtime +30 -delete

echo "[$(date)] 备份完成: $BACKUP_DIR"
```

### 恢复过程
```bash
# 恢复Git仓库
docker exec -i hexo-blog-prod tar -xzf - -C /home/hexo < \
    /backup/hexo-blog/hexo-git-YYYYMMDD_HHMMSS.tar.gz

# 恢复Web内容
docker exec -i hexo-blog-prod tar -xzf - -C /home/www < \
    /backup/hexo-blog/hexo-www-YYYYMMDD_HHMMSS.tar.gz

# 修复权限
docker exec hexo-blog-prod chown -R hexo:hexo /home/hexo /home/www
```

## 🚨 故障排除

### 常见问题及解决方案

#### 1. 容器无法启动
```bash
# 检查日志
docker logs hexo-blog-prod

# 常见原因:
# - 端口冲突: 更改主机端口映射
# - 权限问题: 检查Docker daemon权限
# - 资源不足: 检查内存和磁盘空间
```

#### 2. SSH连接失败
```bash
# 检查SSH服务状态
docker exec hexo-blog-prod systemctl status ssh

# 检查SSH配置
docker exec hexo-blog-prod cat /etc/ssh/sshd_config

# 重启SSH服务
docker exec hexo-blog-prod systemctl restart ssh
```

#### 3. Git推送失败
```bash
# 检查Git仓库权限
docker exec hexo-blog-prod ls -la /home/hexo/hexo.git

# 检查post-receive钩子
docker exec hexo-blog-prod cat /home/hexo/hexo.git/hooks/post-receive

# 手动修复权限
docker exec hexo-blog-prod chown -R hexo:hexo /home/hexo/hexo.git
```

#### 4. Web页面无法访问
```bash
# 检查Nginx状态
docker exec hexo-blog-prod nginx -t
docker exec hexo-blog-prod systemctl status nginx

# 检查Web根目录
docker exec hexo-blog-prod ls -la /home/www/hexo

# 重启Nginx
docker exec hexo-blog-prod systemctl reload nginx
```

## 🔐 安全加固

### 定期安全更新
```bash
# 创建安全更新脚本
cat > /usr/local/bin/hexo-security-update.sh << 'EOF'
#!/bin/bash
CONTAINER_NAME="hexo-blog-prod"

echo "[$(date)] 开始安全更新..."

# 更新容器内的包
docker exec $CONTAINER_NAME apt-get update
docker exec $CONTAINER_NAME apt-get upgrade -y

# 重启服务
docker exec $CONTAINER_NAME systemctl restart ssh
docker exec $CONTAINER_NAME systemctl reload nginx

echo "[$(date)] 安全更新完成"
EOF

# 每月第一个周日凌晨3点执行安全更新
echo "0 3 1-7 * 0 [ \$(date +\%w) -eq 0 ] && /usr/local/bin/hexo-security-update.sh" | crontab -
```

### SSH安全加固
```bash
# 禁用root SSH登录并限制用户
docker exec hexo-blog-prod bash -c "
echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
echo 'AllowUsers hexo' >> /etc/ssh/sshd_config
echo 'MaxAuthTries 3' >> /etc/ssh/sshd_config
echo 'MaxStartups 2' >> /etc/ssh/sshd_config
systemctl restart ssh
"
```

## 📈 性能优化

### Docker资源限制
```bash
# 启动容器时设置资源限制
docker run -d \
  --name hexo-blog-prod \
  --restart unless-stopped \
  --memory=512m \
  --cpus=1.0 \
  --memory-swap=1g \
  -p 80:80 -p 2022:22 \
  hexo-blog:v0.0.3-fixed
```

### 缓存优化
```bash
# 在反向代理中启用缓存
# Nginx示例:
location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
    proxy_pass http://localhost;
    proxy_cache_valid 200 1d;
    add_header X-Cache-Status $upstream_cache_status;
}
```

## 📞 支持与维护

### 联系信息
- **技术支持**: 通过GitHub Issues报告问题
- **文档更新**: 随版本更新自动同步
- **社区讨论**: 加入相关技术论坛

### 维护计划
- **日常监控**: 自动化健康检查和日志分析
- **周期更新**: 每月安全补丁，每季度功能更新
- **备份验证**: 每周备份完整性测试

## 🎯 版本路线图

### v0.0.4 (计划中)
- [ ] 自动SSL证书管理
- [ ] 增强的监控仪表盘
- [ ] 多站点支持
- [ ] 自动化CI/CD集成

### v0.1.0 (长期目标)
- [ ] 集群部署支持
- [ ] CDN集成
- [ ] 高可用配置
- [ ] 企业级安全特性

---

**部署成功指标**:
- ✅ 容器健康状态: healthy
- ✅ Web服务响应: HTTP 200
- ✅ SSH连接正常: 密钥认证成功
- ✅ Git部署功能: 推送自动部署
- ✅ 监控告警: 正常运行
- ✅ 备份恢复: 定期验证

**维护联系**: GitHub Copilot AI Assistant  
**最后更新**: 2025年5月29日 23:50 (CST)
