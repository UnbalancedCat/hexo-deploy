# Hexo Container v0.0.3 运行测试脚本 (Windows)
# run_test.ps1

param(
    [string]$Tag = "hexo-test:v0.0.3",
    [string]$ContainerName = "hexo-test-v003",
    [int]$HttpPort = 8080,
    [int]$SshPort = 2222,
    [int]$Puid = 1000,
    [int]$Pgid = 1000,
    [string]$TimeZone = "Asia/Shanghai"
)

# 确保脚本在正确的目录下执行
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "=== Hexo Container v0.0.3 运行测试 ===" -ForegroundColor Cyan

# 创建日志目录
$LogDir = ".\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# 创建测试数据目录
$TestDataDir = ".\test_data"
$HexoSiteDir = "$TestDataDir\hexo_site"
$SshKeysDir = "$TestDataDir\ssh_keys"

Write-Host "创建测试数据目录..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $HexoSiteDir -Force | Out-Null
New-Item -ItemType Directory -Path $SshKeysDir -Force | Out-Null

# SSH 密钥文件路径定义
$UserSshDir           = Join-Path $env:USERPROFILE ".ssh"
$DefaultPrivateKeyName = "id_rsa"
$DefaultPublicKeyName  = "id_rsa.pub"

$SourceUserPrivateKeyPath = Join-Path $UserSshDir $DefaultPrivateKeyName
$SourceUserPublicKeyPath  = Join-Path $UserSshDir $DefaultPublicKeyName

# $SshKeysDir is already defined as ".\\test_data\\ssh_keys" relative to script dir if Set-Location $ScriptDir is effective.
# For robustness, use absolute paths for targets. $ScriptDir is defined at the start of the script.
$TargetSshKeysDir         = Join-Path $ScriptDir "test_data\\ssh_keys" 

# Ensure $TargetSshKeysDir (which is $SshKeysDir) is created. The script does this above.
# New-Item -ItemType Directory -Path $TargetSshKeysDir -Force | Out-Null # Redundant if $SshKeysDir creation is confirmed above

$TargetPrivateKeyPath     = Join-Path $TargetSshKeysDir "test_key"
$TargetPublicKeyPath      = Join-Path $TargetSshKeysDir "test_key.pub"
$TargetAuthorizedKeysPath = Join-Path $TargetSshKeysDir "authorized_keys"

Write-Host "检查 SSH 密钥文件..." -ForegroundColor Yellow

# 优先: 尝试从用户默认 SSH 目录复制
if ((Test-Path $SourceUserPrivateKeyPath) -and (Test-Path $SourceUserPublicKeyPath)) {
    Write-Host "在用户默认 SSH 目录 ($UserSshDir) 中找到密钥 ($DefaultPrivateKeyName, $DefaultPublicKeyName)。" -ForegroundColor Green
    Write-Host "正在复制 '$DefaultPrivateKeyName' 到 '$TargetPrivateKeyPath'..." -ForegroundColor Gray
    try {
        Copy-Item -Path $SourceUserPrivateKeyPath -Destination $TargetPrivateKeyPath -Force -ErrorAction Stop
        Write-Host "  成功复制私钥。" -ForegroundColor Green
    } catch {
        Write-Host "  警告: 复制私钥 '$SourceUserPrivateKeyPath' 到 '$TargetPrivateKeyPath' 失败: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  请检查源文件权限或目标目录权限。" -ForegroundColor Yellow
    }
    Write-Host "正在复制 '$DefaultPublicKeyName' 到 '$TargetPublicKeyPath'..." -ForegroundColor Gray
    try {
        Copy-Item -Path $SourceUserPublicKeyPath -Destination $TargetPublicKeyPath -Force -ErrorAction Stop
        Write-Host "  成功复制公钥。" -ForegroundColor Green
    } catch {
        Write-Host "  警告: 复制公钥 '$SourceUserPublicKeyPath' 到 '$TargetPublicKeyPath' 失败: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  请检查源文件权限或目标目录权限。" -ForegroundColor Yellow
    }
} else {
    Write-Host "未在用户默认 SSH 目录 ($UserSshDir) 中找到 '$DefaultPrivateKeyName' 和 '$DefaultPublicKeyName'。" -ForegroundColor Yellow
    Write-Host "将检查 '$TargetSshKeysDir' 目录中是否已存在 'test_key' 和 'test_key.pub'。" -ForegroundColor Yellow
}

# 次选/验证: 检查测试数据目录中是否已存在 'test_key' 和 'test_key.pub'
if (-not (Test-Path $TargetPrivateKeyPath) -or -not (Test-Path $TargetPublicKeyPath)) {
    Write-Host "错误: 最终未能获取 SSH 密钥。" -ForegroundColor Red
    Write-Host "  '$($TargetPrivateKeyPath.Split('\\')[-1])' 或 '$($TargetPublicKeyPath.Split('\\')[-1])' 未在 '$TargetSshKeysDir' 目录中找到，" -ForegroundColor Red
    Write-Host "  并且无法从用户默认 SSH 目录 ($UserSshDir) 自动复制。" -ForegroundColor Red
    Write-Host "请执行以下操作之一:" -ForegroundColor Red
    Write-Host "  1. 确保您的默认 SSH 密钥 ($SourceUserPrivateKeyPath 和 $SourceUserPublicKeyPath) 存在且可访问，脚本将尝试自动复制它们。" -ForegroundColor Red
    Write-Host "  2. 或者，手动将您的SSH私钥文件复制到 '$TargetSshKeysDir' 目录，并将其重命名为 'test_key'。" -ForegroundColor Red
    Write-Host "  3. 以及，手动将您对应的SSH公钥文件复制到 '$TargetSshKeysDir' 目录，并将其重命名为 'test_key.pub'。" -ForegroundColor Red
    Write-Host "如果您没有现成的密钥对，请先使用 ssh-keygen 等工具生成它们，并确保它们位于您的默认 SSH 目录或手动复制到测试目录。" -ForegroundColor Red
    exit 1
} else {
    Write-Host "成功确认 'test_key' 和 'test_key.pub' 已存在于 '$TargetSshKeysDir'。" -ForegroundColor Green
}

# 至此， $TargetPrivateKeyPath 和 $TargetPublicKeyPath 应该已存在
Write-Host "处理 SSH 密钥文件并设置权限..." -ForegroundColor Yellow
try {
    # 从 test_key.pub 创建/覆盖 authorized_keys
    Copy-Item -Path $TargetPublicKeyPath -Destination $TargetAuthorizedKeysPath -Force
    Write-Host "已使用 '$TargetPublicKeyPath' 的内容创建/覆盖 '$TargetAuthorizedKeysPath'。" -ForegroundColor Green
    
    # 在Windows上为三个文件设置基本权限
    Write-Host "尝试为 SSH 密钥文件设置本地权限..." -ForegroundColor Gray
    
    $filesToSecure = @($TargetPrivateKeyPath, $TargetPublicKeyPath, $TargetAuthorizedKeysPath)
    foreach ($file in $filesToSecure) {
        icacls $file /inheritance:r /grant:r "$($env:USERNAME):F" /T 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  警告: 设置 '$file' 权限可能失败。请检查文件是否存在以及您是否有权修改权限。" -ForegroundColor Yellow
        } else {
            Write-Host "  成功为 '$file' 设置权限。" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "错误: 处理 SSH 密钥文件或设置权限时发生错误: $($_.Exception.Message)" -ForegroundColor Red
    exit 1 
}

# 创建测试用的 HTML 文件
$TestHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>Hexo v0.0.3 Test Site</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007acc; padding-bottom: 10px; }
        .info { background: #e7f3ff; padding: 15px; border-radius: 4px; margin: 15px 0; }
        .status { display: inline-block; padding: 4px 8px; border-radius: 3px; color: white; background: #28a745; }
        ul { list-style-type: none; padding: 0; }
        li { padding: 8px; margin: 5px 0; background: #f8f9fa; border-left: 4px solid #007acc; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hexo Container v0.0.3 测试站点</h1>
        <div class="info">
            <p><strong>测试时间:</strong> <span id="time"></span></p>
            <p><strong>版本:</strong> <span class="status">v0.0.3</span></p>
            <p><strong>状态:</strong> <span class="status">运行中</span></p>
        </div>
          <h2>v0.0.3 新功能测试</h2>
        <ul>
            <li>定期日志轮转 (每30分钟检查)</li>
            <li>Git Hook 日志权限修复</li>
            <li>增强的部署日志管理</li>
            <li>智能日志文件大小控制</li>
            <li>自动旧日志清理</li>
            <li>时间戳备份文件生成</li>
        </ul>
        
        <h2>测试链接</h2>
        <ul>
            <li><a href="/health">健康检查端点</a></li>
            <li>SSH 连接: ssh -p $SshPort hexo@localhost</li>
        </ul>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString('zh-CN');
    </script>
</body>
</html>
"@

Write-Host "创建测试网站文件..." -ForegroundColor Yellow
$TestHtml | Out-File -FilePath "$HexoSiteDir\index.html" -Encoding UTF8

# 停止并删除已存在的容器
Write-Host "清理旧容器..." -ForegroundColor Yellow
docker stop $ContainerName 2>$null | Out-Null
docker rm $ContainerName 2>$null | Out-Null

# 检查端口是否被占用
$HttpPortInUse = Get-NetTCPConnection -LocalPort $HttpPort -ErrorAction SilentlyContinue
$SshPortInUse = Get-NetTCPConnection -LocalPort $SshPort -ErrorAction SilentlyContinue

if ($HttpPortInUse) {
    Write-Host "警告: 端口 $HttpPort 已被占用" -ForegroundColor Yellow
}
if ($SshPortInUse) {
    Write-Host "警告: 端口 $SshPort 已被占用" -ForegroundColor Yellow
}

# 构建 Docker 运行命令
$DockerCmd = @"
docker run -d ``
  --name $ContainerName ``
  -p $($HttpPort):80 ``
  -p $($SshPort):22 ``
  -e PUID=$Puid ``
  -e PGID=$Pgid ``
  -e TZ=$TimeZone ``
  -e HTTP_PORT=80 ``
  -e SSH_PORT=22 ``  -v "$ScriptDir\test_data\hexo_site:/home/www/hexo" ``
  -v "$ScriptDir\test_data\ssh_keys:/home/hexo/.ssh" ``
  $Tag
"@

Write-Host "`n启动容器..." -ForegroundColor Yellow
Write-Host "执行命令:" -ForegroundColor Gray
Write-Host $DockerCmd -ForegroundColor Gray

# 执行 Docker 运行命令
try {
    $ContainerId = Invoke-Expression $DockerCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=== 容器启动成功 ===" -ForegroundColor Green
        Write-Host "容器 ID: $ContainerId" -ForegroundColor Green
        Write-Host "容器名称: $ContainerName" -ForegroundColor Green
        
        # 等待容器启动
        Write-Host "`n等待容器完全启动..." -ForegroundColor Yellow
        Start-Sleep -Seconds 15
        
        # 检查容器状态
        $ContainerStatus = docker ps --filter "name=$ContainerName" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        Write-Host "`n=== 容器状态 ===" -ForegroundColor Cyan
        Write-Host $ContainerStatus -ForegroundColor Green
        
        # 在容器内修复 authorized_keys 权限
        Write-Host "\\n=== 修复容器内 SSH authorized_keys 权限 ===" -ForegroundColor Cyan
        try {
            Write-Host "在容器内执行: chmod 600 /home/hexo/.ssh/authorized_keys" -ForegroundColor Gray
            docker exec $ContainerName chmod 600 /home/hexo/.ssh/authorized_keys
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[警告] chmod 600 /home/hexo/.ssh/authorized_keys 失败。" -ForegroundColor Yellow
            } else {
                Write-Host "[成功] chmod 600 /home/hexo/.ssh/authorized_keys 执行完毕。" -ForegroundColor Green
            }

            Write-Host "在容器内执行: chown hexo:hexo /home/hexo/.ssh/authorized_keys" -ForegroundColor Gray
            docker exec $ContainerName chown hexo:hexo /home/hexo/.ssh/authorized_keys
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[警告] chown hexo:hexo /home/hexo/.ssh/authorized_keys 失败。" -ForegroundColor Yellow
            } else {
                Write-Host "[成功] chown hexo:hexo /home/hexo/.ssh/authorized_keys 执行完毕。" -ForegroundColor Green
            }
        } catch {
            Write-Host "[错误] 修复 SSH authorized_keys 权限时发生错误: $($_.Exception.Message)" -ForegroundColor Red
        }

          # 显示访问信息
        Write-Host "\\n=== 访问信息 ===" -ForegroundColor Cyan
        Write-Host "HTTP 访问地址: http://localhost:$HttpPort" -ForegroundColor Green
        Write-Host "健康检查地址: http://localhost:$HttpPort/health" -ForegroundColor Green
        Write-Host "SSH 连接命令: ssh -p $SshPort -i .\test_data\ssh_keys\test_key hexo@localhost" -ForegroundColor Green
        
        # 显示容器日志
        Write-Host "`n=== 容器启动日志 (最后20行) ===" -ForegroundColor Cyan
        docker logs $ContainerName --tail 20
          # 基础健康检查
        Write-Host "`n=== 基础健康检查 ===" -ForegroundColor Cyan
        Start-Sleep -Seconds 5
        
        try {
            $HealthResponse = Invoke-WebRequest -Uri "http://localhost:$HttpPort/health" -TimeoutSec 10
            # 修复: 正确处理响应内容
            $Content = if ($HealthResponse.Content -is [byte[]]) { 
                [System.Text.Encoding]::UTF8.GetString($HealthResponse.Content).Trim() 
            } else { 
                $HealthResponse.Content.ToString().Trim() 
            }
            if ($HealthResponse.StatusCode -eq 200 -and ($Content -eq "healthy" -or $Content -eq "OK")) {
                Write-Host "[SUCCESS] 健康检查通过" -ForegroundColor Green
            } else {
                Write-Host "[FAIL] 健康检查失败: $Content" -ForegroundColor Red
            }
        } catch {
            Write-Host "[ERROR] 健康检查失败: $($_.Exception.Message)" -ForegroundColor Red
        }
          try {
            $HttpResponse = Invoke-WebRequest -Uri "http://localhost:$HttpPort" -TimeoutSec 10
            if ($HttpResponse.StatusCode -eq 200) {
                Write-Host "[SUCCESS] HTTP 服务正常" -ForegroundColor Green
            } else {
                Write-Host "[FAIL] HTTP 服务异常: 状态码 $($HttpResponse.StatusCode)" -ForegroundColor Red
            }
        } catch {
            Write-Host "[ERROR] HTTP 服务异常: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Write-Host "`n=== 运行测试完成 ===" -ForegroundColor Cyan
        Write-Host "容器已成功启动并运行。使用以下命令进行进一步测试:" -ForegroundColor Gray
        Write-Host "  .\functional_test.ps1    # 功能测试" -ForegroundColor Gray
        Write-Host "  .\log_rotation_test.ps1  # 日志轮转测试" -ForegroundColor Gray
        Write-Host "  .\cleanup_test.ps1       # 清理测试环境" -ForegroundColor Gray
        
        return $true
        
    } else {
        throw "Docker 容器启动失败"
    }
} catch {
    Write-Host "`n=== 容器启动失败 ===" -ForegroundColor Red
    Write-Host "错误信息: $($_.Exception.Message)" -ForegroundColor Red
    
    # 尝试显示错误日志
    try {
        Write-Host "`n=== 容器错误日志 ===" -ForegroundColor Yellow
        docker logs $ContainerName
    } catch {
        Write-Host "无法获取容器日志" -ForegroundColor Red
    }
    
    return $false
}
