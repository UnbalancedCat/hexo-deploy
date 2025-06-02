# Hexo Container v0.0.3 清理脚本
# cleanup_test.ps1 - 清理测试环境和资源

param(
    [switch]$Force = $false,
    [switch]$KeepImages = $false,
    [switch]$KeepLogs = $false,
    [switch]$DeepClean = $false,
    [string]$ContainerName = "hexo-test-v003*",
    [string]$ImageTag = "hexo*",
    [switch]$Interactive = $true
)

# 确保脚本在正确的目录下执行
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "=== Hexo Container v0.0.3 清理脚本 ===" -ForegroundColor Cyan
Write-Host "此脚本将清理测试环境中的容器、镜像和日志文件" -ForegroundColor Gray

# 获取时间戳用于备份
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

# 创建清理日志
$LogDir = ".\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$CleanupLog = "$LogDir\cleanup_$TimeStamp.log"

# 记录清理开始
"=== 清理操作开始 $(Get-Date) ===" | Add-Content $CleanupLog

# 函数：安全确认
function Confirm-Action {
    param([string]$Message, [switch]$Force)
    
    if ($Force) {
        Write-Host "FORCE 模式: $Message" -ForegroundColor Yellow
        return $true
    }
    
    if (-not $Interactive) {
        return $true
    }
    
    Write-Host "$Message" -ForegroundColor Yellow
    $response = Read-Host "继续吗? (y/N)"
    return ($response -eq "y" -or $response -eq "Y" -or $response -eq "yes")
}

# 函数：停止并删除容器
function Remove-TestContainers {
    param([string]$Pattern, [bool]$Force)
    
    Write-Host "`n=== 清理容器 ===" -ForegroundColor Cyan
    
    # 获取匹配的容器
    $Containers = docker ps -a --filter "name=$Pattern" --format "{{.Names}}" 2>$null
    
    if (-not $Containers) {
        Write-Host "未找到匹配的容器: $Pattern" -ForegroundColor Green
        "未找到匹配的容器: $Pattern" | Add-Content $CleanupLog
        return
    }
    
    Write-Host "找到以下容器:" -ForegroundColor Gray
    $Containers | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    if (Confirm-Action "删除这些容器?" -Force:$Force) {
        foreach ($container in $Containers) {
            Write-Host "停止容器: $container" -ForegroundColor Yellow
            docker stop $container 2>$null | Out-Null
            
            Write-Host "删除容器: $container" -ForegroundColor Yellow  
            docker rm $container 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "SUCCESS: 容器 $container 已删除" -ForegroundColor Green
                "SUCCESS: 容器 $container 已删除" | Add-Content $CleanupLog
            } else {
                Write-Host "ERROR: 删除容器 $container 失败" -ForegroundColor Red
                "ERROR: 删除容器 $container 失败" | Add-Content $CleanupLog
            }
        }
    } else {
        Write-Host "用户取消了容器清理操作" -ForegroundColor Yellow
    }
}

# 函数：删除镜像
function Remove-TestImages {
    param([string]$Pattern, [bool]$Force)
    
    Write-Host "`n=== 清理镜像 ===" -ForegroundColor Cyan
    
    # 获取匹配的镜像
    $Images = docker images --filter "reference=$Pattern" --format "{{.Repository}}:{{.Tag}}" 2>$null
    
    if (-not $Images) {
        Write-Host "未找到匹配的镜像: $Pattern" -ForegroundColor Green
        "未找到匹配的镜像: $Pattern" | Add-Content $CleanupLog
        return
    }
    
    Write-Host "找到以下镜像:" -ForegroundColor Gray
    $Images | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    if (Confirm-Action "删除这些镜像?" -Force:$Force) {
        foreach ($image in $Images) {
            Write-Host "删除镜像: $image" -ForegroundColor Yellow
            docker rmi $image 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "SUCCESS: 镜像 $image 已删除" -ForegroundColor Green
                "SUCCESS: 镜像 $image 已删除" | Add-Content $CleanupLog
            } else {
                Write-Host "WARNING: 删除镜像 $image 失败（可能被其他容器使用）" -ForegroundColor Yellow
                "WARNING: 删除镜像 $image 失败" | Add-Content $CleanupLog
            }
        }
    } else {
        Write-Host "用户取消了镜像清理操作" -ForegroundColor Yellow
    }
}

# 函数：清理日志文件
function Remove-TestLogs {
    param([bool]$Force, [bool]$DeepClean)
    
    Write-Host "`n=== 清理日志文件 ===" -ForegroundColor Cyan
    
    # 检查日志目录
    if (-not (Test-Path $LogDir)) {
        Write-Host "日志目录不存在: $LogDir" -ForegroundColor Green
        return
    }
    
    # 获取日志文件
    $LogFiles = Get-ChildItem $LogDir -File -Recurse | Where-Object { 
        $_.Extension -eq ".log" -or $_.Extension -eq ".txt" 
    }
    
    if (-not $LogFiles) {
        Write-Host "未找到日志文件" -ForegroundColor Green
        return
    }
    
    Write-Host "找到 $($LogFiles.Count) 个日志文件" -ForegroundColor Gray
    
    if ($DeepClean) {
        # 深度清理：删除所有日志文件
        if (Confirm-Action "深度清理：删除所有日志文件?" -Force:$Force) {
            $LogFiles | ForEach-Object {
                Write-Host "删除: $($_.Name)" -ForegroundColor Gray
                Remove-Item $_.FullName -Force
            }
            Write-Host "SUCCESS: 所有日志文件已删除" -ForegroundColor Green
            "SUCCESS: 深度清理完成，删除了 $($LogFiles.Count) 个日志文件" | Add-Content $CleanupLog
        }
    } else {
        # 普通清理：归档旧日志文件
        $OldLogsDir = "$LogDir\old_$TimeStamp"
        
        if (Confirm-Action "将日志文件归档到 old_$TimeStamp 文件夹?" -Force:$Force) {
            New-Item -ItemType Directory -Path $OldLogsDir -Force | Out-Null
            
            $LogFiles | ForEach-Object {
                if ($_.Name -ne "cleanup_$TimeStamp.log") {  # 保留当前清理日志
                    Write-Host "归档: $($_.Name)" -ForegroundColor Gray
                    Move-Item $_.FullName $OldLogsDir -Force
                }
            }
            Write-Host "SUCCESS: 日志文件已归档到 $OldLogsDir" -ForegroundColor Green
            "SUCCESS: 日志文件已归档到 $OldLogsDir" | Add-Content $CleanupLog
        }
    }
}

# 函数：清理SSH密钥
function Remove-TestSSHKeys {
    param([bool]$Force)
    
    Write-Host "`n=== 清理SSH密钥 ===" -ForegroundColor Cyan
    
    $SshKeyDir = ".\test_data\ssh_keys"
    if (-not (Test-Path $SshKeyDir)) {
        Write-Host "SSH密钥目录不存在: $SshKeyDir" -ForegroundColor Green
        return
    }
    
    # 查找临时生成的密钥文件
    $TempKeys = Get-ChildItem $SshKeyDir -File | Where-Object { 
        $_.Name -match "temp_" -or $_.Name -match "test_key" -or $_.Name -match "container_key"
    }
    
    if (-not $TempKeys) {
        Write-Host "未找到临时SSH密钥文件" -ForegroundColor Green
        return
    }
    
    Write-Host "找到以下临时SSH密钥:" -ForegroundColor Gray
    $TempKeys | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }
    
    if (Confirm-Action "删除这些临时SSH密钥?" -Force:$Force) {
        $TempKeys | ForEach-Object {
            Write-Host "删除: $($_.Name)" -ForegroundColor Gray
            Remove-Item $_.FullName -Force
        }
        Write-Host "SUCCESS: 临时SSH密钥已删除" -ForegroundColor Green
        "SUCCESS: 删除了 $($TempKeys.Count) 个临时SSH密钥" | Add-Content $CleanupLog
    }
}

# 函数：Docker系统清理
function Invoke-DockerSystemClean {
    param([bool]$Force)
    
    Write-Host "`n=== Docker系统清理 ===" -ForegroundColor Cyan
    
    if (Confirm-Action "执行 docker system prune 清理未使用的资源?" -Force:$Force) {
        Write-Host "执行 docker system prune..." -ForegroundColor Yellow
        docker system prune -f 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "SUCCESS: Docker系统清理完成" -ForegroundColor Green
            "SUCCESS: Docker系统清理完成" | Add-Content $CleanupLog
        } else {
            Write-Host "WARNING: Docker系统清理失败" -ForegroundColor Yellow
            "WARNING: Docker系统清理失败" | Add-Content $CleanupLog
        }
    }
}

# 主清理流程
Write-Host "`n开始清理操作..." -ForegroundColor Yellow

# 1. 清理容器
Remove-TestContainers -Pattern $ContainerName -Force $Force

# 2. 清理镜像（如果不保留）
if (-not $KeepImages) {
    Remove-TestImages -Pattern $ImageTag -Force $Force
}

# 3. 清理日志文件（如果不保留）
if (-not $KeepLogs) {
    Remove-TestLogs -Force $Force -DeepClean $DeepClean
}

# 4. 清理SSH密钥
Remove-TestSSHKeys -Force $Force

# 5. Docker系统清理（如果深度清理）
if ($DeepClean) {
    Invoke-DockerSystemClean -Force $Force
}

# 显示清理结果
Write-Host "`n=== 清理完成 ===" -ForegroundColor Cyan

# 检查剩余资源
Write-Host "`n剩余资源状态:" -ForegroundColor Gray

Write-Host "  容器:" -ForegroundColor Gray
$RemainingContainers = docker ps -a --filter "name=hexo*" --format "{{.Names}}" 2>$null
if ($RemainingContainers) {
    $RemainingContainers | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
} else {
    Write-Host "    无相关容器" -ForegroundColor Green
}

Write-Host "  镜像:" -ForegroundColor Gray
$RemainingImages = docker images --filter "reference=hexo*" --format "{{.Repository}}:{{.Tag}}" 2>$null
if ($RemainingImages) {
    $RemainingImages | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
} else {
    Write-Host "    无相关镜像" -ForegroundColor Green
}

Write-Host "  日志文件:" -ForegroundColor Gray
if (Test-Path $LogDir) {
    $RemainingLogs = Get-ChildItem $LogDir -File -Recurse | Where-Object { 
        $_.Extension -eq ".log" -or $_.Extension -eq ".txt" 
    }
    if ($RemainingLogs) {
        Write-Host "    $($RemainingLogs.Count) 个文件" -ForegroundColor Yellow
    } else {
        Write-Host "    无日志文件" -ForegroundColor Green
    }
} else {
    Write-Host "    无日志目录" -ForegroundColor Green
}

# 记录清理完成
"=== 清理操作完成 $(Get-Date) ===" | Add-Content $CleanupLog

Write-Host "`n清理日志: $CleanupLog" -ForegroundColor Gray
Write-Host "清理操作完成！" -ForegroundColor Green

# 用法提示
Write-Host "`n用法示例:" -ForegroundColor Cyan
Write-Host "  .\cleanup_test.ps1                    # 交互式清理" -ForegroundColor Gray
Write-Host "  .\cleanup_test.ps1 -Force             # 强制清理，无确认" -ForegroundColor Gray
Write-Host "  .\cleanup_test.ps1 -KeepImages        # 保留镜像" -ForegroundColor Gray
Write-Host "  .\cleanup_test.ps1 -KeepLogs          # 保留日志" -ForegroundColor Gray
Write-Host "  .\cleanup_test.ps1 -DeepClean         # 深度清理" -ForegroundColor Gray
Write-Host "  .\cleanup_test.ps1 -Force -DeepClean  # 强制深度清理" -ForegroundColor Gray
