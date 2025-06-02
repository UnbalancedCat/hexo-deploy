# v0.0.4-enhanced 自动化测试脚本
# 执行方式: PowerShell -ExecutionPolicy Bypass -File test_v0.0.4-enhanced.ps1

param(
    [switch]$Cleanup = $false,
    [switch]$SkipBuild = $false,
    [string]$LogFile = "test_results_v0.0.4_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# 颜色输出函数
function Write-TestResult {
    param([string]$Message, [string]$Status)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] $Message - $Status"
    
    switch ($Status) {
        "PASS" { Write-Host $logEntry -ForegroundColor Green }
        "FAIL" { Write-Host $logEntry -ForegroundColor Red }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "INFO" { Write-Host $logEntry -ForegroundColor Cyan }
        default { Write-Host $logEntry }
    }
    
    # 同时写入日志文件
    $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

# 测试结果记录
$TestResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Warnings = 0
    StartTime = Get-Date
}

function Test-Condition {
    param([string]$TestName, [scriptblock]$TestBlock)
    
    $TestResults.TotalTests++
    Write-TestResult "开始测试: $TestName" "INFO"
    
    try {
        $result = & $TestBlock
        if ($result -eq $true -or $result -eq "PASS") {
            $TestResults.PassedTests++
            Write-TestResult "$TestName" "PASS"
            return $true
        } else {
            $TestResults.FailedTests++
            Write-TestResult "$TestName - $result" "FAIL"
            return $false
        }
    } catch {
        $TestResults.FailedTests++
        Write-TestResult "$TestName - 异常: $($_.Exception.Message)" "FAIL"
        return $false
    }
}

# 开始测试
Write-TestResult "=== v0.0.4-enhanced 自动化测试开始 ===" "INFO"
Write-TestResult "日志文件: $LogFile" "INFO"

# 清理环境
if ($Cleanup) {
    Write-TestResult "清理旧环境..." "INFO"
    docker stop hexo-blog-enhanced 2>$null | Out-Null
    docker rm hexo-blog-enhanced 2>$null | Out-Null
    docker rmi hexo-blog:enhanced 2>$null | Out-Null
}

# 构建镜像
if (-not $SkipBuild) {
    Write-TestResult "构建v0.0.4-enhanced镜像..." "INFO"
    $buildOutput = docker build -f Dockerfile_v0.0.4-enhanced -t hexo-blog:enhanced . 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult "镜像构建成功" "PASS"
    } else {
        Write-TestResult "镜像构建失败: $buildOutput" "FAIL"
        exit 1
    }
}

# 启动容器
Write-TestResult "启动增强版容器..." "INFO"
$containerStart = Get-Date
docker run -d --name hexo-blog-enhanced --restart unless-stopped `
    -p 8080:80 -p 2222:22 `
    --health-interval=30s --health-timeout=10s --health-retries=3 `
    hexo-blog:enhanced | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-TestResult "容器启动命令执行成功" "PASS"
} else {
    Write-TestResult "容器启动失败" "FAIL"
    exit 1
}

# 等待容器完全启动
Write-TestResult "等待容器初始化..." "INFO"
$maxWait = 60
$waited = 0
do {
    Start-Sleep -Seconds 2
    $waited += 2
    $status = docker inspect hexo-blog-enhanced --format='{{.State.Status}}' 2>$null
} while ($status -ne "running" -and $waited -lt $maxWait)

$containerReady = Get-Date
$startupTime = ($containerReady - $containerStart).TotalSeconds
Write-TestResult "容器启动耗时: $startupTime 秒" "INFO"

# 测试1: 容器健康状态
Test-Condition "容器健康状态检查" {
    $health = docker inspect hexo-blog-enhanced --format='{{.State.Health.Status}}' 2>$null
    if ($health -eq "healthy" -or $health -eq "starting") {
        return $true
    } else {
        return "健康状态: $health"
    }
}

# 测试2: Web服务基础访问
Test-Condition "Web服务基础访问" {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            return $true
        } else {
            return "状态码: $($response.StatusCode)"
        }
    } catch {
        return "连接失败: $($_.Exception.Message)"
    }
}

# 测试3: 健康检查端点
Test-Condition "健康检查端点" {
    try {
        $health = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing -TimeoutSec 5
        if ($health.Content -match "healthy") {
            return $true
        } else {
            return "健康检查返回: $($health.Content)"
        }
    } catch {
        return "健康检查端点访问失败"
    }
}

# 测试4: 状态API端点 (v0.0.4新增)
Test-Condition "状态API端点" {
    try {
        $status = Invoke-WebRequest -Uri "http://localhost:8080/status" -UseBasicParsing -TimeoutSec 5
        $statusData = $status.Content | ConvertFrom-Json
        if ($statusData.status -eq "ok" -and $statusData.version) {
            return $true
        } else {
            return "状态API格式异常"
        }
    } catch {
        return "状态API访问失败或JSON解析失败"
    }
}

# 测试5: SSH连接
Test-Condition "SSH密钥认证" {
    if (-not (Test-Path "hexo_key")) {
        return "SSH密钥文件不存在"
    }
    
    try {
        $sshTest = ssh -i hexo_key -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes -p 2222 hexo@localhost "echo 'SSH_TEST_OK'" 2>$null
        if ($sshTest -match "SSH_TEST_OK") {
            return $true
        } else {
            return "SSH连接失败或认证失败"
        }
    } catch {
        return "SSH测试异常"
    }
}

# 测试6: Supervisor进程管理 (v0.0.4特性)
Test-Condition "Supervisor进程管理" {
    try {
        $supervisorStatus = docker exec hexo-blog-enhanced supervisorctl status 2>$null
        if ($supervisorStatus -match "RUNNING") {
            return $true
        } else {
            return "Supervisor状态异常: $supervisorStatus"
        }
    } catch {
        return "Supervisor不可用或未安装"
    }
}

# 测试7: Fail2ban安全服务 (v0.0.4特性)
Test-Condition "Fail2ban安全服务" {
    try {
        $fail2banStatus = docker exec hexo-blog-enhanced systemctl is-active fail2ban 2>$null
        if ($fail2banStatus -eq "active") {
            return $true
        } else {
            return "Fail2ban状态: $fail2banStatus"
        }
    } catch {
        return "Fail2ban检查失败"
    }
}

# 测试8: Nginx性能配置
Test-Condition "Nginx性能配置" {
    try {
        $workerConfig = docker exec hexo-blog-enhanced grep "worker_connections" /etc/nginx/nginx.conf 2>$null
        if ($workerConfig -match "4096") {
            return $true
        } else {
            return "Worker连接数配置未生效: $workerConfig"
        }
    } catch {
        return "Nginx配置检查失败"
    }
}

# 测试9: Gzip压缩功能
Test-Condition "Gzip压缩功能" {
    try {
        $gzipTest = Invoke-WebRequest -Uri "http://localhost:8080" -Headers @{"Accept-Encoding"="gzip"} -UseBasicParsing
        if ($gzipTest.Headers.'Content-Encoding' -eq "gzip") {
            return $true
        } else {
            return "Gzip压缩未启用"
        }
    } catch {
        return "Gzip测试失败"
    }
}

# 测试10: 内存使用检查
Test-Condition "内存使用合理性" {
    try {
        $memStats = docker stats hexo-blog-enhanced --no-stream --format "{{.MemUsage}}"
        $memUsage = [regex]::Match($memStats, "(\d+(?:\.\d+)?)(\w+)").Groups[1].Value
        $memUnit = [regex]::Match($memStats, "(\d+(?:\.\d+)?)(\w+)").Groups[2].Value
        
        $memMB = switch ($memUnit) {
            "MiB" { [float]$memUsage }
            "GiB" { [float]$memUsage * 1024 }
            "kB" { [float]$memUsage / 1024 }
            default { [float]$memUsage }
        }
        
        if ($memMB -lt 200) {  # 200MB限制
            return $true
        } else {
            return "内存使用过高: ${memMB}MB"
        }
    } catch {
        return "内存检查失败"
    }
}

# 测试11: Git部署功能
Test-Condition "Git部署功能" {
    if (-not (Test-Path "hexo_key")) {
        return "SSH密钥不存在，跳过Git测试"
    }
    
    try {
        # 配置Git远程
        git remote remove docker 2>$null | Out-Null
        git remote add docker ssh://hexo@localhost:2222/home/hexo/hexo.git 2>$null
        $env:GIT_SSH_COMMAND = "ssh -i $(Get-Location)\hexo_key -o StrictHostKeyChecking=no"
        
        # 创建测试文件
        $testContent = "# v0.0.4自动化测试`n测试时间: $(Get-Date)"
        $testContent | Out-File -FilePath "test_auto_v0.0.4.md" -Encoding UTF8
        
        git add test_auto_v0.0.4.md 2>$null
        git commit -m "v0.0.4自动化测试部署" 2>$null
        
        # 推送部署
        $pushResult = git push docker main 2>&1
        if ($LASTEXITCODE -eq 0) {
            # 验证部署结果
            Start-Sleep -Seconds 3
            $deployCheck = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing
            if ($deployCheck.Content -match "v0.0.4自动化测试") {
                Remove-Item "test_auto_v0.0.4.md" -Force 2>$null
                return $true
            } else {
                return "部署内容未更新"
            }
        } else {
            return "Git推送失败: $pushResult"
        }
    } catch {
        return "Git部署测试异常: $($_.Exception.Message)"
    }
}

# 测试完成，生成报告
$TestResults.EndTime = Get-Date
$TestResults.Duration = ($TestResults.EndTime - $TestResults.StartTime).TotalSeconds

Write-TestResult "=== 测试完成 ===" "INFO"
Write-TestResult "总测试数: $($TestResults.TotalTests)" "INFO"
Write-TestResult "通过: $($TestResults.PassedTests)" "INFO"
Write-TestResult "失败: $($TestResults.FailedTests)" "INFO"
Write-TestResult "耗时: $([math]::Round($TestResults.Duration, 1)) 秒" "INFO"

$successRate = [math]::Round(($TestResults.PassedTests / $TestResults.TotalTests) * 100, 1)
Write-TestResult "成功率: $successRate%" "INFO"

# 生成总结
if ($TestResults.FailedTests -eq 0) {
    Write-TestResult "🎉 所有测试通过！v0.0.4-enhanced 可以投入生产使用" "PASS"
    $exitCode = 0
} elseif ($successRate -ge 80) {
    Write-TestResult "⚠️  大部分测试通过，但存在问题需要修复" "WARN"
    $exitCode = 1
} else {
    Write-TestResult "❌ 多项测试失败，建议回滚到v0.0.3-fixed" "FAIL"
    $exitCode = 2
}

Write-TestResult "详细测试日志已保存到: $LogFile" "INFO"

# 清理测试环境 (可选)
if ($Cleanup) {
    Write-TestResult "清理测试环境..." "INFO"
    docker stop hexo-blog-enhanced 2>$null | Out-Null
    docker rm hexo-blog-enhanced 2>$null | Out-Null
}

exit $exitCode
