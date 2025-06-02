# 路径测试脚本 - 验证所有测试脚本的路径配置是否正确
# test_paths.ps1

param()

# 确保脚本在正确的目录下执行
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "=== 测试脚本路径验证 ===" -ForegroundColor Cyan
Write-Host "当前脚本目录: $ScriptDir" -ForegroundColor Green
Write-Host "当前工作目录: $(Get-Location)" -ForegroundColor Green

# 检查关键文件和目录
$PathsToCheck = @{
    "Dockerfile_v0.0.3" = "..\..\..\Dockerfile_v0.0.3"
    "logs目录" = ".\logs"
    "test_data目录" = ".\test_data"
    "test_data\hexo_site目录" = ".\test_data\hexo_site"
    "test_data\ssh_keys目录" = ".\test_data\ssh_keys"
    "build_test.ps1" = ".\build_test.ps1"
    "run_test.ps1" = ".\run_test.ps1"
    "functional_test.ps1" = ".\functional_test.ps1"
    "log_rotation_test.ps1" = ".\log_rotation_test.ps1"
    "cleanup_test.ps1" = ".\cleanup_test.ps1"
    "start.ps1" = ".\start.ps1"
}

Write-Host "`n=== 路径检查结果 ===" -ForegroundColor Cyan

foreach ($Description in $PathsToCheck.Keys) {
    $Path = $PathsToCheck[$Description]
    $AbsolutePath = Join-Path $ScriptDir $Path
    
    if (Test-Path $AbsolutePath) {
        Write-Host "[✓] $Description`: $Path" -ForegroundColor Green
    } else {
        Write-Host "[✗] $Description`: $Path (不存在)" -ForegroundColor Red
    }
}

# 检查必需的目录，不存在则创建
Write-Host "`n=== 创建必需目录 ===" -ForegroundColor Cyan

$RequiredDirs = @(".\logs", ".\test_data", ".\test_data\hexo_site", ".\test_data\ssh_keys")

foreach ($Dir in $RequiredDirs) {
    if (-not (Test-Path $Dir)) {
        try {
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
            Write-Host "[CREATE] 已创建目录: $Dir" -ForegroundColor Yellow
        } catch {
            Write-Host "[ERROR] 无法创建目录 $Dir`: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "[EXISTS] 目录已存在: $Dir" -ForegroundColor Green
    }
}

# 测试 Docker 命令路径构建
Write-Host "`n=== Docker 命令路径测试 ===" -ForegroundColor Cyan

$DockerfilePath = "..\..\..\Dockerfile_v0.0.3"
$DockerfileAbsPath = Join-Path $ScriptDir $DockerfilePath
$DockerContext = Split-Path $DockerfileAbsPath -Parent

Write-Host "Dockerfile 相对路径: $DockerfilePath" -ForegroundColor Gray
Write-Host "Dockerfile 绝对路径: $DockerfileAbsPath" -ForegroundColor Gray
Write-Host "Docker 构建上下文: $DockerContext" -ForegroundColor Gray

if (Test-Path $DockerfileAbsPath) {
    Write-Host "[✓] Dockerfile 路径正确" -ForegroundColor Green
} else {
    Write-Host "[✗] Dockerfile 路径错误" -ForegroundColor Red
}

# 测试卷挂载路径
Write-Host "`n=== 卷挂载路径测试 ===" -ForegroundColor Cyan

$VolumePaths = @{
    "hexo_site" = "$ScriptDir\test_data\hexo_site"
    "ssh_keys" = "$ScriptDir\test_data\ssh_keys"
    "logs" = "$ScriptDir\logs"
}

foreach ($VolumeName in $VolumePaths.Keys) {
    $Path = $VolumePaths[$VolumeName]
    Write-Host "卷 $VolumeName`: $Path" -ForegroundColor Gray
    
    if (Test-Path $Path) {
        Write-Host "[✓] 路径存在" -ForegroundColor Green
    } else {
        Write-Host "[✗] 路径不存在" -ForegroundColor Red
    }
}

Write-Host "`n=== 路径验证完成 ===" -ForegroundColor Cyan
Write-Host "如果所有路径都正确，可以开始运行测试脚本。" -ForegroundColor Gray
