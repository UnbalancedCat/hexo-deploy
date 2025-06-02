# v0.0.4-enhanced 测试计划与执行指南
**版本**: v0.0.4-enhanced | **测试日期**: 2025年5月30日 | **状态**: 🧪 测试准备中

---

## 📋 测试前准备

### 1. 环境准备
```powershell
# 清理旧容器和镜像
docker stop hexo-blog 2>$null; docker rm hexo-blog 2>$null
docker rmi hexo-blog:enhanced 2>$null

# 确保端口可用
netstat -ano | findstr ":8080\|:2222"
if ($LASTEXITCODE -eq 0) {
    Write-Warning "端口被占用，请先清理"
}
```

### 2. 构建测试镜像
```powershell
# 构建v0.0.4-enhanced镜像
docker build -f Dockerfile_v0.0.4-enhanced -t hexo-blog:enhanced .

# 验证镜像创建
docker images | findstr hexo-blog
```

### 3. 启动增强版容器
```powershell
# 使用增强版启动脚本
cp start_v0.0.4-enhanced.sh start.sh

# 启动容器
docker run -d --name hexo-blog-enhanced --restart unless-stopped `
  -p 8080:80 -p 2222:22 `
  --health-interval=30s --health-timeout=10s --health-retries=3 `
  hexo-blog:enhanced

# 等待容器完全启动
Start-Sleep -Seconds 20
```

---

## 🧪 功能测试清单

### 基础服务测试

#### 1. 容器健康状态
```powershell
# 检查容器状态
docker ps | findstr hexo-blog-enhanced
docker inspect hexo-blog-enhanced --format='{{.State.Health.Status}}'

# 预期结果: healthy
```

#### 2. Web服务测试
```powershell
# 基础Web访问
$response = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing
Write-Output "Web服务状态: $($response.StatusCode)"

# 健康检查端点
$health = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing
Write-Output "健康检查: $($health.Content)"

# 新增状态端点
$status = Invoke-WebRequest -Uri "http://localhost:8080/status" -UseBasicParsing
Write-Output "状态API: $($status.Content)"

# 预期结果: 
# - Web服务状态: 200
# - 健康检查: healthy
# - 状态API: JSON格式状态信息
```

#### 3. SSH服务测试
```powershell
# SSH连接测试
ssh -i hexo_key -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p 2222 hexo@localhost "echo 'SSH v0.0.4测试成功'"

# SSH配置验证
ssh -i hexo_key -p 2222 hexo@localhost "sudo sshd -T | grep -E 'maxauthtries|maxsessions|logingracetime'"

# 预期结果:
# - SSH连接成功
# - 安全配置已生效 (MaxAuthTries 3, MaxSessions 5, etc.)
```

### 增强功能测试

#### 4. Supervisor进程管理
```powershell
# 检查Supervisor状态
docker exec hexo-blog-enhanced supervisorctl status

# 测试服务重启
docker exec hexo-blog-enhanced supervisorctl restart nginx
docker exec hexo-blog-enhanced supervisorctl restart sshd

# 验证服务自动恢复
Start-Sleep -Seconds 5
docker exec hexo-blog-enhanced supervisorctl status

# 预期结果: 所有服务显示RUNNING状态
```

#### 5. 安全加固验证
```powershell
# 检查Fail2ban状态
docker exec hexo-blog-enhanced systemctl is-active fail2ban
docker exec hexo-blog-enhanced fail2ban-client status

# SSH安全配置验证
docker exec hexo-blog-enhanced grep -E "MaxAuthTries|MaxSessions|LoginGraceTime" /etc/ssh/sshd_config

# Nginx安全标头检查
$headers = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing
$headers.Headers | findstr -i "security\|content-security\|strict-transport"

# 预期结果:
# - Fail2ban: active
# - SSH安全配置已应用
# - Nginx安全标头已设置
```

#### 6. 性能优化验证
```powershell
# Nginx worker配置检查
docker exec hexo-blog-enhanced grep -E "worker_connections|keepalive_requests" /etc/nginx/nginx.conf

# Gzip压缩测试
$gzipTest = Invoke-WebRequest -Uri "http://localhost:8080" -Headers @{"Accept-Encoding"="gzip"} -UseBasicParsing
Write-Output "Gzip压缩: $($gzipTest.Headers.'Content-Encoding')"

# 并发连接测试 (简单版)
for ($i=1; $i -le 10; $i++) {
    Start-Job -ScriptBlock { Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing }
}
Get-Job | Wait-Job | Receive-Job | Measure-Object | Select-Object Count

# 预期结果:
# - worker_connections: 4096
# - Gzip压缩启用
# - 并发请求成功处理
```

### Git部署功能测试

#### 7. Git部署增强功能
```powershell
# 配置Git部署
git remote remove docker 2>$null
git remote add docker ssh://hexo@localhost:2222/home/hexo/hexo.git
$env:GIT_SSH_COMMAND = "ssh -i $(Get-Location)\hexo_key -o StrictHostKeyChecking=no"

# 创建测试内容
echo "# v0.0.4增强版测试" > test_v0.0.4.md
echo "测试时间: $(Get-Date)" >> test_v0.0.4.md
git add test_v0.0.4.md
git commit -m "v0.0.4增强版部署测试"

# 执行Git推送
git push docker main

# 检查部署日志
docker exec hexo-blog-enhanced cat /var/log/hexo-deploy.log | tail -20

# 检查备份功能
docker exec hexo-blog-enhanced ls -la /backup/auto/ 2>/dev/null || echo "备份目录未找到"

# 验证部署结果
$deployResult = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing
if ($deployResult.Content -match "v0.0.4增强版测试") {
    Write-Output "✅ Git部署成功"
} else {
    Write-Output "❌ Git部署可能失败"
}

# 预期结果:
# - Git推送成功
# - 部署日志记录详细信息
# - 自动备份创建 (如果配置)
# - 网站内容更新
```

### 监控和日志测试

#### 8. 日志系统验证
```powershell
# 检查日志轮转配置
docker exec hexo-blog-enhanced ls -la /var/log/ | findstr nginx
docker exec hexo-blog-enhanced ls -la /var/log/ | findstr ssh

# Supervisor日志检查
docker exec hexo-blog-enhanced ls -la /var/log/supervisor/

# 系统日志检查
docker logs hexo-blog-enhanced --tail 20

# 预期结果: 日志文件存在且轮转正常
```

#### 9. 监控端点测试
```powershell
# 详细状态检查
$statusAPI = Invoke-WebRequest -Uri "http://localhost:8080/status" -UseBasicParsing
$statusData = $statusAPI.Content | ConvertFrom-Json
Write-Output "版本: $($statusData.version)"
Write-Output "状态: $($statusData.status)"

# Nginx状态检查 (如果启用)
try {
    $nginxStatus = Invoke-WebRequest -Uri "http://localhost:8080/nginx_status" -UseBasicParsing
    Write-Output "Nginx状态: 已启用"
} catch {
    Write-Output "Nginx状态: 未启用或不可访问"
}

# 预期结果: JSON格式状态信息返回正确
```

---

## 📊 性能基准测试

### 10. 性能对比测试
```powershell
# 启动时间测试
$startTime = Get-Date
docker restart hexo-blog-enhanced
do {
    Start-Sleep -Seconds 1
    $health = docker inspect hexo-blog-enhanced --format='{{.State.Health.Status}}' 2>$null
} while ($health -ne "healthy")
$endTime = Get-Date
$startupTime = ($endTime - $startTime).TotalSeconds
Write-Output "启动时间: $startupTime 秒"

# 内存使用检查
$memUsage = docker stats hexo-blog-enhanced --no-stream --format "table {{.MemUsage}}"
Write-Output "内存使用: $memUsage"

# 简单负载测试
$loadTestStart = Get-Date
for ($i=1; $i -le 50; $i++) {
    Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing | Out-Null
}
$loadTestEnd = Get-Date
$loadTestTime = ($loadTestEnd - $loadTestStart).TotalSeconds
Write-Output "50次请求耗时: $loadTestTime 秒"

# 预期结果:
# - 启动时间 < 15秒
# - 内存使用合理 (< 150MB)
# - 负载测试响应良好
```

---

## 🔍 问题诊断和调试

### 故障排除命令
```powershell
# 完整系统状态检查
function Test-HexoBlogEnhanced {
    Write-Output "=== v0.0.4增强版系统诊断 ==="
    
    # 容器状态
    Write-Output "`n1. 容器状态:"
    docker ps | findstr hexo-blog-enhanced
    
    # 健康检查
    Write-Output "`n2. 健康检查:"
    docker inspect hexo-blog-enhanced --format='{{.State.Health.Status}}'
    
    # 服务状态
    Write-Output "`n3. 内部服务状态:"
    docker exec hexo-blog-enhanced supervisorctl status
    
    # 端口监听
    Write-Output "`n4. 端口监听:"
    docker exec hexo-blog-enhanced ss -tlnp | findstr ":80\|:22"
    
    # 磁盘使用
    Write-Output "`n5. 磁盘使用:"
    docker exec hexo-blog-enhanced df -h
    
    # 最新日志
    Write-Output "`n6. 最新日志:"
    docker logs hexo-blog-enhanced --tail 10
    
    Write-Output "`n=== 诊断完成 ==="
}

# 执行诊断
Test-HexoBlogEnhanced
```

---

## ✅ 测试结果记录模板

### 测试执行记录
```
测试日期: ___________
测试人员: ___________
Docker版本: ___________
主机系统: ___________

基础功能测试:
□ 容器启动健康检查 - 通过/失败 (耗时: ___秒)
□ Web服务访问 - 通过/失败
□ SSH连接认证 - 通过/失败
□ 健康检查端点 - 通过/失败
□ 状态API端点 - 通过/失败

增强功能测试:
□ Supervisor进程管理 - 通过/失败
□ Fail2ban安全防护 - 通过/失败  
□ SSH安全加固 - 通过/失败
□ Nginx性能优化 - 通过/失败
□ Gzip压缩功能 - 通过/失败

Git部署测试:
□ Git推送部署 - 通过/失败
□ 自动备份功能 - 通过/失败 (如果启用)
□ 部署日志记录 - 通过/失败
□ 内容更新验证 - 通过/失败

性能测试:
□ 启动时间 - ___秒 (目标: <15秒)
□ 内存使用 - ___MB (目标: <150MB)  
□ 并发处理 - 通过/失败
□ 负载测试 - ___秒/50请求

发现问题:
1. ___________________
2. ___________________
3. ___________________

总体评价: 通过/失败
生产建议: 推荐/需要改进/不推荐
```

---

## 🚀 下一步行动

### 测试通过后
1. 📄 生成正式测试报告
2. 📚 更新生产部署文档
3. 🔄 创建版本比较报告
4. 📈 制定生产迁移计划

### 测试失败处理
1. 🐛 记录具体错误信息
2. 🔧 回滚到v0.0.3-fixed
3. 📝 分析失败原因
4. 🛠️ 制定修复计划

---

*测试指南版本: v1.0 | 创建日期: 2025年5月30日*
