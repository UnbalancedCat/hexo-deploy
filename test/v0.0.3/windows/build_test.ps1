# Hexo Container v0.0.3 构建测试脚本 (Windows)
# build_test.ps1

param(
    [string]$Tag = "hexo-test:v0.0.3",
    [string]$Platform = "linux/amd64",
    [string]$DockerfilePath = "..\..\..\Dockerfile_v0.0.3"
)

# 确保脚本在正确的目录下执行
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "=== Hexo Container v0.0.3 构建测试 ===" -ForegroundColor Cyan
Write-Host "镜像标签: $Tag" -ForegroundColor Green
Write-Host "平台架构: $Platform" -ForegroundColor Green
Write-Host "Dockerfile: $DockerfilePath" -ForegroundColor Green

# 检查 Dockerfile 是否存在
if (-not (Test-Path $DockerfilePath)) {
    Write-Host "错误: Dockerfile 不存在: $DockerfilePath" -ForegroundColor Red
    exit 1
}

# 创建日志目录
$LogDir = ".\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# 如果这是独立运行的构建测试，清理旧的构建测试文件
if ($MyInvocation.ScriptName -eq $PSCommandPath) {
    Write-Host "=== 清理旧的构建测试文件 ===" -ForegroundColor Cyan
    $OldLogsDir = "$LogDir\old"
    if (-not (Test-Path $OldLogsDir)) {
        New-Item -ItemType Directory -Path $OldLogsDir -Force | Out-Null
        Write-Host "创建旧日志归档目录: $OldLogsDir" -ForegroundColor Gray
    }

    # 移动旧的构建测试文件到 old 文件夹
    $OldBuildFiles = Get-ChildItem $LogDir -File | Where-Object { 
        $_.Name -match "build_.*\.log$" 
    }

    if ($OldBuildFiles.Count -gt 0) {
        Write-Host "归档 $($OldBuildFiles.Count) 个旧构建测试文件到 old 文件夹..." -ForegroundColor Gray
        foreach ($file in $OldBuildFiles) {
            $destPath = Join-Path $OldLogsDir $file.Name
            Move-Item $file.FullName $destPath -Force
            Write-Host "  移动: $($file.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "没有旧的构建测试文件需要归档" -ForegroundColor Gray
    }
}

# 记录开始时间
$StartTime = Get-Date
$LogFile = "$LogDir\build_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

Write-Host "构建开始时间: $StartTime" -ForegroundColor Yellow
Write-Host "日志文件: $LogFile" -ForegroundColor Yellow

# 执行构建
Write-Host "`n开始构建镜像..." -ForegroundColor Yellow

try {
    # 获取 Dockerfile 的绝对路径
    $DockerfileAbsPath = Join-Path $ScriptDir $DockerfilePath
    $DockerContext = Split-Path $DockerfileAbsPath -Parent
    
    $BuildCmd = "docker build -f `"$DockerfileAbsPath`" -t $Tag --platform $Platform `"$DockerContext`""
    Write-Host "执行命令: $BuildCmd" -ForegroundColor Gray
    
    # 执行构建并捕获输出
    $BuildOutput = Invoke-Expression $BuildCmd 2>&1
    $BuildOutput | Out-File -FilePath $LogFile -Encoding UTF8
    
    if ($LASTEXITCODE -eq 0) {
        $EndTime = Get-Date
        $Duration = $EndTime - $StartTime
        
        Write-Host "`n=== 构建成功 ===" -ForegroundColor Green
        Write-Host "构建结束时间: $EndTime" -ForegroundColor Green
        Write-Host "构建耗时: $($Duration.TotalMinutes.ToString('F2')) 分钟" -ForegroundColor Green
        
        # 显示镜像信息
        Write-Host "`n=== 镜像信息 ===" -ForegroundColor Cyan
        docker images $Tag
        
        # 显示镜像详细信息
        Write-Host "`n=== 镜像详细信息 ===" -ForegroundColor Cyan
        $ImageInfo = docker inspect $Tag | ConvertFrom-Json
        $ImageSize = [math]::Round($ImageInfo[0].Size / 1MB, 2)
        Write-Host "镜像大小: $ImageSize MB" -ForegroundColor Green
        Write-Host "创建时间: $($ImageInfo[0].Created)" -ForegroundColor Green
        Write-Host "架构: $($ImageInfo[0].Architecture)" -ForegroundColor Green
        
        # 输出构建统计
        Write-Host "`n=== 构建统计 ===" -ForegroundColor Cyan
        $LayerCount = ($BuildOutput | Select-String "^Step \d+/\d+").Count
        Write-Host "构建步骤数: $LayerCount" -ForegroundColor Green
        
        return $true
    } else {
        throw "Docker build 命令执行失败"
    }
} catch {
    Write-Host "`n=== 构建失败 ===" -ForegroundColor Red
    Write-Host "错误信息: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "详细日志请查看: $LogFile" -ForegroundColor Red
    
    # 显示最后几行日志
    if (Test-Path $LogFile) {
        Write-Host "`n=== 最后10行构建日志 ===" -ForegroundColor Yellow
        Get-Content $LogFile | Select-Object -Last 10 | ForEach-Object {
            Write-Host $_ -ForegroundColor Gray
        }
    }
    
    return $false
}

Write-Host "`n构建测试完成。" -ForegroundColor Cyan
Write-Host "详细日志保存在: $LogFile" -ForegroundColor Gray
