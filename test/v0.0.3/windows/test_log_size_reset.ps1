# 专用于测试日志大小重置功能的脚本
# test_log_size_reset_fixed.ps1

param(
    [string]$ContainerName = "hexo-test-v003",
    [int]$SshPort = 2222,
    [string]$SshKeyPath = ".\test_data\ssh_keys\test_key",
    [int]$TargetSizeKB = 25,  # 目标大小，超过20KB阈值
    [switch]$Verbose = $false
)

# 确保脚本在正确的目录下执行
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# 确保 SSH 密钥路径为绝对路径
$SshKeyPath = Join-Path $ScriptDir "test_data\ssh_keys\test_key"

Write-Host "=== 日志大小重置功能专项测试 ===" -ForegroundColor Cyan
Write-Host "目标: 验证日志文件超过 20KB 时能否正确重置" -ForegroundColor Gray

# 创建日志目录
$LogDir = ".\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$TestLog = "$LogDir\log_size_reset_test_$TimeStamp.log"

# 检查容器是否运行
Write-Host "`n检查容器状态..." -ForegroundColor Yellow
$ContainerRunning = docker ps --filter "name=$ContainerName" --format "{{.Names}}" | Select-String $ContainerName
if (-not $ContainerRunning) {
    Write-Host "ERROR: 容器 $ContainerName 未运行" -ForegroundColor Red
    exit 1
}
Write-Host "SUCCESS: 容器正在运行" -ForegroundColor Green

# 检查 SSH 密钥
if (-not (Test-Path $SshKeyPath)) {
    Write-Host "ERROR: SSH 密钥不存在: $SshKeyPath" -ForegroundColor Red
    exit 1
}

# 函数：清理重复的deployment.log文件
function Clear-DuplicateDeploymentLogs {
    param([string]$ContainerName)
    
    $bashScript = @'
cd /var/log/container
# Check if there are duplicate deployment.log files
LOG_COUNT=$(ls -1 deployment.log 2>/dev/null | wc -l)
if [ $LOG_COUNT -gt 1 ]; then
    echo 'Found duplicate deployment.log files, cleaning up...'
    # Remove all deployment.log files and recreate one
    rm -f deployment.log
    touch deployment.log
    chown hexo:hexo deployment.log
    chmod 664 deployment.log
    echo 'Duplicate files cleaned'
elif [ $LOG_COUNT -eq 0 ]; then
    touch deployment.log
    chown hexo:hexo deployment.log
    chmod 664 deployment.log
else
    chown hexo:hexo deployment.log
    chmod 664 deployment.log
fi
'@
    
    docker exec $ContainerName bash -c $bashScript
}

# 修复权限
Write-Host "`n修复日志文件权限..." -ForegroundColor Yellow
$bashScript = 'cd /var/log/container && UNIQUE_FILES=$(find . -name "deployment.log" -type f -exec ls -li {} \; 2>/dev/null | awk "{print \$1}" | sort -u | wc -l 2>/dev/null || echo 0) && if [ "$UNIQUE_FILES" -gt 1 ]; then echo "Found $UNIQUE_FILES unique deployment.log files, removing all duplicates..." && find . -name "deployment.log" -type f -delete 2>/dev/null || true; fi && mkdir -p /var/log/container && if [ ! -f /var/log/container/deployment.log ]; then touch /var/log/container/deployment.log; fi && chown hexo:hexo /var/log/container/deployment.log && chmod 664 /var/log/container/deployment.log && echo "Single deployment.log file ensured with correct permissions"'

docker exec $ContainerName bash -c $bashScript

# 清理重复的deployment.log文件
Clear-DuplicateDeploymentLogs -ContainerName $ContainerName

# 函数：获取日志文件大小
function Get-LogFileSize {
    param([string]$LogPath)
    try {
        $bashScript = 'stat -c%s ' + $LogPath + ' 2>/dev/null || echo 0'
        $SizeBytes = docker exec $ContainerName bash -c $bashScript
        if ($null -eq $SizeBytes -or $SizeBytes -eq "") {
            return 0
        }
        return [int]$SizeBytes
    } catch {
        return 0
    }
}

# 函数：获取备份文件数量
function Get-BackupFileCount {
    try {
        $bashScript = 'LANG=C ls -la /var/log/container/ | grep "deployment\.log\.[0-9]" | wc -l'
        $BackupCount = docker exec $ContainerName bash -c $bashScript
        return [int]$BackupCount
    } catch {
        return 0
    }
}

# 函数：获取唯一的文件列表（去重）
function Get-UniqueFileList {
    param([string]$Pattern)
    try {
        # 使用find命令更精确地查找文件，避免重复
        $bashScript = 'LANG=C find /var/log/container/ -name "deployment.log*" -type f | sort | xargs ls -la'
        $FileList = docker exec $ContainerName bash -c $bashScript
        
        # 去重处理
        if ($FileList) {
            $UniqueFiles = $FileList | Sort-Object | Get-Unique
            return $UniqueFiles
        } else {
            return @()
        }
    } catch {
        return @()
    }
}

# 函数：生成指定大小的日志
function Generate-LogToSize {
    param([int]$TargetSizeKB)
    
    $TargetBytes = $TargetSizeKB * 1024
    $LogEntrySize = 150  # 估算单条日志大小
    $RequiredEntries = [Math]::Ceiling($TargetBytes / $LogEntrySize)
    
    Write-Host "目标大小: $TargetSizeKB KB ($TargetBytes bytes)" -ForegroundColor Yellow
    Write-Host "预计需要生成: $RequiredEntries 条日志" -ForegroundColor Yellow
    
    $BatchSize = 50
    $BatchCount = [Math]::Ceiling($RequiredEntries / $BatchSize)
    
    for ($batch = 1; $batch -le $BatchCount; $batch++) {
        $EntriesInBatch = if ($batch -eq $BatchCount) { 
            $RequiredEntries - (($batch - 1) * $BatchSize)
        } else { 
            $BatchSize 
        }
        
        Write-Host "批次 $batch/$BatchCount : 生成 $EntriesInBatch 条日志..." -ForegroundColor Gray
        
        for ($i = 1; $i -le $EntriesInBatch; $i++) {
            $CurrentTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'            $LogMessage = "SIZE_TEST_ENTRY_${batch}_${i} : $CurrentTime - 这是用于测试日志大小重置功能的测试条目。此条目包含足够的内容以达到预期的文件大小。批次${batch}，条目${i}。"
            try {
                ssh -p $SshPort -i $SshKeyPath -o ConnectTimeout=10 -o StrictHostKeyChecking=no hexo@localhost "echo '$LogMessage' >> /var/log/container/deployment.log"
                
                if ($Verbose -and ($i % 10 -eq 0)) {
                    $CurrentSize = Get-LogFileSize "/var/log/container/deployment.log"
                    Write-Host "  已生成 $i/$EntriesInBatch 条，当前大小: $([math]::Round($CurrentSize / 1024, 2)) KB" -ForegroundColor Gray
                }
                
                Start-Sleep -Milliseconds 5
            } catch {
                Write-Host "生成日志失败: $($_.Exception.Message)" -ForegroundColor Red
                break
            }
        }
        
        # 检查当前大小
        $CurrentSize = Get-LogFileSize "/var/log/container/deployment.log"
        Write-Host "批次 $batch 完成，当前大小: $([math]::Round($CurrentSize / 1024, 2)) KB" -ForegroundColor Green
        
        # 如果已经达到目标大小，提前退出
        if ($CurrentSize -ge $TargetBytes) {
            Write-Host "已达到目标大小，停止生成" -ForegroundColor Green
            break
        }
    }
}

# 开始测试
"=== 日志大小重置测试开始 $(Get-Date) ===" | Add-Content $TestLog

Write-Host "`n=== 步骤 1: 检查初始状态 ===" -ForegroundColor Cyan
$InitialSize = Get-LogFileSize "/var/log/container/deployment.log"
$InitialBackupCount = Get-BackupFileCount

Write-Host "初始日志大小: $([math]::Round($InitialSize / 1024, 2)) KB" -ForegroundColor Gray
Write-Host "初始备份文件数: $InitialBackupCount" -ForegroundColor Gray

"初始状态 - 大小: $InitialSize bytes, 备份文件: $InitialBackupCount" | Add-Content $TestLog

Write-Host "`n=== 步骤 2: 生成日志至目标大小 ===" -ForegroundColor Cyan
Generate-LogToSize -TargetSizeKB $TargetSizeKB

Write-Host "`n=== 步骤 3: 检查轮转前状态 ===" -ForegroundColor Cyan
$PreRotationSize = Get-LogFileSize "/var/log/container/deployment.log"
$PreRotationBackupCount = Get-BackupFileCount

Write-Host "轮转前日志大小: $([math]::Round($PreRotationSize / 1024, 2)) KB" -ForegroundColor Gray
Write-Host "轮转前备份文件数: $PreRotationBackupCount" -ForegroundColor Gray

# 显示详细的文件列表
$FileList = Get-UniqueFileList "deployment.log*"
Write-Host "轮转前文件列表:" -ForegroundColor Gray
if ($FileList -and $FileList.Count -gt 0) {
    $FileList | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "  未找到相关文件" -ForegroundColor Gray
}

Write-Host "`n=== 步骤 4: 手动触发日志轮转 ===" -ForegroundColor Cyan
if ($PreRotationSize -gt (20 * 1024)) {
    Write-Host "日志大小超过 20KB 阈值，触发轮转..." -ForegroundColor Yellow
    # 手动强制执行 logrotate
    $bashScript = 'logrotate -f /etc/logrotate.d/deployment && echo "ROTATE_SUCCESS"'
    $RotateResult = docker exec $ContainerName bash -c $bashScript
    
    if ($RotateResult -eq "ROTATE_SUCCESS") {
        Write-Host "SUCCESS: logrotate 执行成功" -ForegroundColor Green
    } else {
        Write-Host "WARNING: logrotate 执行可能失败" -ForegroundColor Yellow
        Write-Host "返回结果: $RotateResult" -ForegroundColor Gray
    }
    
    # 等待一下确保轮转完成
    Start-Sleep -Seconds 2
} else {
    Write-Host "WARNING: 日志大小未超过 20KB 阈值，无法测试轮转" -ForegroundColor Yellow
}

Write-Host "`n=== 步骤 5: 检查轮转后状态 ===" -ForegroundColor Cyan
$PostRotationSize = Get-LogFileSize "/var/log/container/deployment.log"
$PostRotationBackupCount = Get-BackupFileCount

Write-Host "轮转后日志大小: $([math]::Round($PostRotationSize / 1024, 2)) KB" -ForegroundColor Gray
Write-Host "轮转后备份文件数: $PostRotationBackupCount" -ForegroundColor Gray

# 显示轮转后的文件列表
$PostFileList = Get-UniqueFileList "deployment.log*"
Write-Host "轮转后文件列表:" -ForegroundColor Gray
if ($PostFileList -and $PostFileList.Count -gt 0) {
    $PostFileList | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "  未找到相关文件" -ForegroundColor Gray
}

Write-Host "`n=== 步骤 6: 分析轮转效果 ===" -ForegroundColor Cyan

# 分析结果
$TestResults = @()

# 测试1: 检查是否生成了足够大的日志
if ($PreRotationSize -gt (20 * 1024)) {
    $TestResults += "日志大小达标: PASS - 达到 $([math]::Round($PreRotationSize / 1024, 2)) KB"
} else {
    $TestResults += "日志大小达标: FAIL - 仅达到 $([math]::Round($PreRotationSize / 1024, 2)) KB，未超过 20KB"
}

# 测试2: 检查日志大小是否被重置
if ($PostRotationSize -lt $PreRotationSize) {
    $TestResults += "日志大小重置: PASS - 从 $([math]::Round($PreRotationSize / 1024, 2)) KB 重置为 $([math]::Round($PostRotationSize / 1024, 2)) KB"
} else {
    $TestResults += "日志大小重置: FAIL - 大小未发生变化"
}

# 测试3: 检查是否创建了备份文件
if ($PostRotationBackupCount -gt $PreRotationBackupCount) {
    $TestResults += "备份文件创建: PASS - 备份文件从 $PreRotationBackupCount 增加到 $PostRotationBackupCount"
} else {
    $TestResults += "备份文件创建: FAIL - 未创建新的备份文件"
}

# 测试4: 检查权限是否正确
$bashScript = 'LANG=C ls -la /var/log/container/deployment.log | awk "{print \$3, \$4}"'
$LogPermission = docker exec $ContainerName bash -c $bashScript
if ($LogPermission -match "hexo hexo") {
    $TestResults += "权限检查: PASS - 权限为 hexo:hexo"
} else {
    $TestResults += "权限检查: FAIL - 权限为 '$LogPermission'"
}

# 计算成功率
$TotalTests = $TestResults.Count
$PassedTests = ($TestResults | Where-Object { $_ -match "PASS" }).Count
$FailedTests = $TotalTests - $PassedTests
$SuccessRate = [Math]::Round(($PassedTests / $TotalTests) * 100, 2)

Write-Host "`n=== 测试结果汇总 ===" -ForegroundColor Cyan
Write-Host "总测试项: $TotalTests" -ForegroundColor Gray
Write-Host "通过: $PassedTests" -ForegroundColor Green
Write-Host "失败: $FailedTests" -ForegroundColor Red
Write-Host "成功率: $SuccessRate%" -ForegroundColor Gray

Write-Host "`n详细结果:" -ForegroundColor Gray
$TestResults | ForEach-Object { 
    if ($_ -match "PASS") {
        Write-Host "  $_" -ForegroundColor Green
    } else {
        Write-Host "  $_" -ForegroundColor Red
    }
}

# 保存测试日志
$LogContent = @"
=== 日志大小重置测试结果 ===
测试时间: $(Get-Date)
容器名称: $ContainerName
目标大小: $TargetSizeKB KB

=== 测试过程 ===
初始大小: $([math]::Round($InitialSize / 1024, 2)) KB
生成后大小: $([math]::Round($PreRotationSize / 1024, 2)) KB
轮转后大小: $([math]::Round($PostRotationSize / 1024, 2)) KB

初始备份文件: $InitialBackupCount
轮转后备份文件: $PostRotationBackupCount

=== 测试结果 ===
总测试项: $TotalTests
通过: $PassedTests
失败: $FailedTests
成功率: $SuccessRate%

详细结果:
$($TestResults | ForEach-Object { "  $_" } | Out-String)
"@

$LogContent | Out-File -FilePath $TestLog -Encoding UTF8

Write-Host "`n详细测试日志: $TestLog" -ForegroundColor Gray

# 根据结果设置退出代码
if ($FailedTests -eq 0) {
    Write-Host "`nSUCCESS: 日志大小重置功能测试通过！" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nWARNING: 部分测试失败，请检查配置。" -ForegroundColor Yellow
    exit 1
}
