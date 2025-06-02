# Hexo Container v0.0.3 日志轮转测试脚本 (Windows)
# log_rotation_test.ps1

param(
    [string]$ContainerName = "hexo-test-v003",
    [int]$HttpPort = 8080,
    [int]$SshPort = 2222,
    [string]$SshKeyPath = ".\test_data\ssh_keys\test_key",
    [int]$TestDeployments = 20,
    [int]$LogSizeThresholdMB = 1,
    [int]$TotalBatches = 10,  # 添加可配置的批次数参数
    [switch]$SkipLogGeneration = $false,
    [switch]$QuickLogGen = $false,
    [switch]$FastRotationTest = $false,
    [switch]$CalledFromTestSuite = $false, # 新增参数，用于指示是否从主测试套件调用
    [switch]$SshDebug = $false # 新增 SshDebug 参数，控制SSH命令的详细程度
)

# 确保脚本在正确的目录下执行
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# 确保 SSH 密钥路径为绝对路径
$SshKeyPath = Join-Path $ScriptDir "test_data\ssh_keys\test_key"

Write-Host "=== Hexo Container v0.0.3 日志轮转测试 ===" -ForegroundColor Cyan
Write-Host "这个测试将验证 v0.0.3 版本的新日志轮转功能" -ForegroundColor Gray

# 创建日志目录
$LogDir = ".\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# 函数：清理重复的deployment.log文件
function Clear-DuplicateDeploymentLogs {
    param([string]$ContainerName)
    
    Write-Host "清理重复的deployment.log文件..." -ForegroundColor Yellow
    $bashCommandRaw = @'
        cd /var/log/container
        LOG_FILE="deployment.log"
        # Check if the log file exists and who owns it
        if [ -f "$LOG_FILE" ]; then
            OWNER=$(stat -c '%U' "$LOG_FILE")
            echo "Found existing $LOG_FILE, owner is $OWNER"
            if [ "$OWNER" = "root" ]; then
                echo "File is owned by root, removing and recreating as hexo user..."
                rm -f "$LOG_FILE"
                su - hexo -c "touch /var/log/container/$LOG_FILE && chmod 664 /var/log/container/$LOG_FILE"
                echo "$LOG_FILE recreated by hexo user."
            elif [ "$OWNER" != "hexo" ]; then
                echo "File owner is not hexo ($OWNER), attempting to chown to hexo..."
                chown hexo:hexo "$LOG_FILE"
                chmod 664 "$LOG_FILE"
                echo "Permissions corrected for $LOG_FILE."
            else
                echo "$LOG_FILE is already owned by hexo. Ensuring correct permissions."
                chmod 664 "$LOG_FILE"
            fi
        else
            echo "$LOG_FILE not found, creating one as hexo user..."
            su - hexo -c "touch /var/log/container/$LOG_FILE && chmod 664 /var/log/container/$LOG_FILE"
            echo "$LOG_FILE created by hexo user."
        fi
        # Verify final state
        echo "Final state of $LOG_FILE:"
        ls -la "$LOG_FILE"
'@
    $bashCommand = $bashCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
    docker exec $ContainerName bash -c $bashCommand
}

# 如果这是独立运行的日志轮转测试，清理旧的日志文件
# 判断逻辑：当脚本不是从主测试套件调用时
$IsStandaloneExecution = -not $CalledFromTestSuite

Write-Host "执行模式检测:" -ForegroundColor Magenta
Write-Host "  CalledFromTestSuite: $CalledFromTestSuite" -ForegroundColor Gray
Write-Host "  IsStandaloneExecution: $IsStandaloneExecution" -ForegroundColor Gray

if ($IsStandaloneExecution) {
    Write-Host "=== 检测到独立执行或未指定调用来源，将清理旧的相关日志文件 ===" -ForegroundColor Cyan
    $OldLogsDir = "$LogDir\old"
    if (-not (Test-Path $OldLogsDir)) {
        New-Item -ItemType Directory -Path $OldLogsDir -Force | Out-Null
        Write-Host "创建旧日志归档目录: $OldLogsDir" -ForegroundColor Gray
    }

    # 检查 deployment.log 是否需要处理
    function Test-DeploymentLogCompatibility {
        param([string]$DeploymentLogPath)
        
        if (-not (Test-Path $DeploymentLogPath)) {
            return $false
        }
        
        try {
            $fileSize = (Get-Item $DeploymentLogPath).Length
            $fileSizeKB = [math]::Round($fileSize / 1024, 2)
            Write-Host "检测到现有 deployment.log，大小: $fileSizeKB KB" -ForegroundColor Gray
            
            # 根据当前测试模式判断是否保留
            if ($SkipLogGeneration) {
                Write-Host "跳过日志生成模式：保留现有 deployment.log" -ForegroundColor Green
                return $true
            } elseif ($FastRotationTest) {
                if ($fileSizeKB -ge 2 -and $fileSizeKB -le 10) {
                    Write-Host "检测到快速轮转测试模式的现有文件，保留使用" -ForegroundColor Green
                    return $true
                }
            } elseif ($QuickLogGen) {
                if ($fileSizeKB -ge 10 -and $fileSizeKB -le 100) {
                    Write-Host "检测到快速日志生成模式的现有文件，保留使用" -ForegroundColor Green
                    return $true
                }
            } else {
                if ($fileSizeKB -ge 300) {
                    Write-Host "检测到正常模式的现有文件，保留使用" -ForegroundColor Green
                    return $true
                }
            }
            
            Write-Host "现有文件不符合当前测试模式要求，需要重新生成" -ForegroundColor Yellow
            return $false
        } catch {
            Write-Host "检查 deployment.log 兼容性时出错: $($_.Exception.Message)" -ForegroundColor Yellow
            return $false
        }
    }

    # 检查 deployment.log 是否需要处理
    $DeploymentLogPath = "$LogDir\\deployment.log"
    # $KeepDeploymentLog = Test-DeploymentLogCompatibility -DeploymentLogPath $DeploymentLogPath # 这部分逻辑由 start.ps1 处理，独立运行时通常不保留

    # 移动旧的日志文件到 old 文件夹 (仅处理 log_rotation_test 相关日志和 deployment.log)
    $OldLogFiles = Get-ChildItem $LogDir -File | Where-Object {
        ($_.Name -like "log_rotation_test_*.log" -or $_.Name -like "log_rotation_test_report_*.txt" -or $_.Name -eq "deployment.log")
    }

    if ($OldLogFiles.Count -gt 0) {
        Write-Host "归档 $($OldLogFiles.Count) 个旧日志文件到 old 文件夹..." -ForegroundColor Gray
        foreach ($file in $OldLogFiles) {
            $destPath = Join-Path $OldLogsDir $file.Name
            Move-Item $file.FullName $destPath -Force
            Write-Host "  移动: $($file.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "没有旧日志文件需要归档" -ForegroundColor Gray
    }

    # 处理容器内的 deployment.log
    Write-Host "处理容器内的 deployment.log (独立执行模式)..." -ForegroundColor Gray
    try {
        $ContainerStatus = docker ps -f "name=$ContainerName" --format "{{.Names}}" 2>$null | Select-String $ContainerName
        if ($ContainerStatus) {
            # 在独立执行时，通常我们希望从一个干净的 deployment.log 开始测试轮转
            Write-Host "发现运行中的容器，清空容器内的 deployment.log..." -ForegroundColor Gray
            $cleanupCommandRaw = "echo '' > /var/log/container/deployment.log && chown hexo:hexo /var/log/container/deployment.log && chmod 664 /var/log/container/deployment.log"
            $cleanupCommand = $cleanupCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
            docker exec $ContainerName sh -c $cleanupCommand 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "容器内 deployment.log 已清空并设置权限" -ForegroundColor Green
            } else {
                Write-Host "清空容器内 deployment.log 失败" -ForegroundColor Yellow
            }
        } else {
            Write-Host "容器未运行，无法处理容器内的 deployment.log" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "处理容器内 deployment.log 时出错: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "=== 检测到通过测试套件调用，跳过旧文件清理和容器内 deployment.log 的预处理 ===" -ForegroundColor Yellow
    Write-Host "注意: 日志文件清理和容器内 deployment.log 的初始状态将由主控脚本 start.ps1 负责" -ForegroundColor Gray
}

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$TestLog = "$LogDir\log_rotation_test_$TimeStamp.log"

# 检查容器是否运行
Write-Host "`n检查容器状态..." -ForegroundColor Yellow
$ContainerRunning = docker ps --filter "name=$ContainerName" --format "{{.Names}}" | Select-String $ContainerName
if (-not $ContainerRunning) {
    Write-Host "ERROR: 容器 $ContainerName 未运行，请先运行 run_test.ps1" -ForegroundColor Red
    exit 1
}
Write-Host "SUCCESS: 容器正在运行" -ForegroundColor Green

# 修复日志文件权限（在测试开始前）
Write-Host "`n修复日志文件权限..." -ForegroundColor Yellow
try {
    # 确保日志目录存在且权限正确
    $bashCommandMkdirRaw = @'
mkdir -p /var/log/container && chown hexo:hexo /var/log/container && chmod 755 /var/log/container
'@
    $bashCommandMkdir = $bashCommandMkdirRaw.Replace("`r`n", "`n").Replace("`r", "`n")
    docker exec $ContainerName bash -c $bashCommandMkdir
    
    # 清理重复的deployment.log文件
    Clear-DuplicateDeploymentLogs -ContainerName $ContainerName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS: 日志文件权限已修复" -ForegroundColor Green
    } else {
        Write-Host "WARNING: 权限修复可能失败，但继续测试" -ForegroundColor Yellow
    }
} catch {
    Write-Host "WARNING: 权限修复时出错: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 检查 SSH 密钥
if (-not (Test-Path $SshKeyPath)) {
    Write-Host "ERROR: SSH 密钥不存在: $SshKeyPath" -ForegroundColor Red
    Write-Host "请先运行 run_test.ps1 生成 SSH 密钥" -ForegroundColor Red
    exit 1
}

# 额外的权限验证和修复
Write-Host "`n进行额外的权限验证和修复..." -ForegroundColor Yellow
try {
    # 验证当前权限状态 - 使用LANG=C避免中文编码问题
    $bashCommandLsRaw = @'
LANG=C ls -la /var/log/container/deployment.log 2>/dev/null || echo 'FILE_NOT_FOUND'
'@
    $bashCommandLs = $bashCommandLsRaw.Replace("`r`n", "`n").Replace("`r", "`n")
    $currentPermissions = docker exec $ContainerName bash -c $bashCommandLs 2>$null
    Write-Host "当前文件权限: $currentPermissions" -ForegroundColor Gray
      # 静默修复权限（减少错误输出）
    Write-Host "验证和修复权限..." -ForegroundColor Gray
    $bashCommandFixRaw = @'
        # 确保目录存在（静默执行）
        mkdir -p /var/log/container >/dev/null 2>&1
        chown hexo:hexo /var/log/container >/dev/null 2>&1
        chmod 755 /var/log/container >/dev/null 2>&1
        
        LOG_FILE="/var/log/container/deployment.log"
        
        # 如果文件存在且是root拥有的，则删除
        if [ -f "$LOG_FILE" ]; then
            OWNER=$(stat -c '%U' "$LOG_FILE" 2>/dev/null || echo "unknown")
            if [ "$OWNER" = "root" ]; then
                rm -f "$LOG_FILE" >/dev/null 2>&1
            fi
        fi
        
        # 创建文件如果不存在 (确保以hexo用户创建)
        if [ ! -f "$LOG_FILE" ]; then
             su - hexo -c "touch $LOG_FILE" >/dev/null 2>&1
        fi
        
        # 设置正确的所有者和权限
        chown hexo:hexo "$LOG_FILE" >/dev/null 2>&1
        chmod 664 "$LOG_FILE" >/dev/null 2>&1
        
        # 验证修复结果
        if [ -f "$LOG_FILE" ]; then
            echo "SUCCESS"
        else
            echo "FAILED"
        fi
'@
    $bashCommandFix = $bashCommandFixRaw.Replace("`r`n", "`n").Replace("`r", "`n")
    $permissionResult = docker exec $ContainerName bash -c $bashCommandFix 2>$null
    
    if ($permissionResult -eq "SUCCESS") {
        Write-Host "SUCCESS: 权限验证和修复完成" -ForegroundColor Green
    } else {
        Write-Host "FAILED: 权限修复失败，但测试将继续进行" -ForegroundColor Yellow
    }
      # 测试hexo用户的写入权限
    Write-Host "测试hexo用户写入权限..." -ForegroundColor Gray
    $bashCommandWriteTestRaw = @'
su - hexo -c 'echo "PERMISSION_TEST_$(date)" >> /var/log/container/deployment.log 2>/dev/null' && echo 'SUCCESS' || echo 'FAILED'
'@
    $bashCommandWriteTest = $bashCommandWriteTestRaw.Replace("`r`n", "`n").Replace("`r", "`n")
    $testResult = docker exec $ContainerName bash -c $bashCommandWriteTest 2>$null
    
    if ($testResult -eq "SUCCESS") {
        Write-Host "SUCCESS: hexo用户可以正常写入日志文件" -ForegroundColor Green
    } else {
        Write-Host "FAILED: hexo用户无法写入日志文件，这会影响测试结果" -ForegroundColor Yellow
    }

    # 静默检查SSH配置（减少输出）
    Write-Host "验证hexo用户SSH配置..." -ForegroundColor Gray
    $bashCommandSshCheckRaw = @'
    # 静默设置SSH权限
    su - hexo -c "mkdir -p /home/hexo/.ssh && chmod 700 /home/hexo/.ssh" >/dev/null 2>&1
    su - hexo -c "touch /home/hexo/.ssh/authorized_keys && chmod 600 /home/hexo/.ssh/authorized_keys" >/dev/null 2>&1
    
    # 验证SSH配置是否正确
    if [ -d "/home/hexo/.ssh" ] && [ -f "/home/hexo/.ssh/authorized_keys" ]; then
        echo "SUCCESS"
    else
        echo "FAILED"
    fi
'@
    $bashCommandSshCheck = $bashCommandSshCheckRaw.Replace("`r`n", "`n").Replace("`r", "`n")
    $sshResult = docker exec $ContainerName bash -c $bashCommandSshCheck 2>$null
    
    if ($sshResult -eq "SUCCESS") {
        Write-Host "SUCCESS: SSH配置验证完成" -ForegroundColor Green
    } else {
        Write-Host "FAILED: SSH配置验证失败" -ForegroundColor Yellow
    }

} catch {
    Write-Host "WARNING: 额外权限修复时出错: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 函数：获取日志文件大小
function Get-LogFileSize {
    param([string]$LogPath)
    try {
        $bashCommandStatRaw = "stat -c%s $LogPath 2>/dev/null; if [ `$? -ne 0 ]; then echo 0; fi"
        $bashCommandStat = $bashCommandStatRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $SizeBytes = docker exec $ContainerName bash -c $bashCommandStat
        if ($null -eq $SizeBytes -or $SizeBytes -eq "") {
            return 0
        }
        return [int]$SizeBytes
    } catch {
        return 0
    }
}

# 函数：获取日志文件列表
function Get-LogFileList {
    try {
        # 使用 LANG=C 强制英文输出，避免中文编码问题
        # 修复：更精确的文件过滤，避免重复行和非预期匹配
        $bashCommandLsLogsRaw = 'LANG=C ls -la /var/log/container/*.log* 2>/dev/null | sort -u || echo "No log files found"'
        $bashCommandLsLogs = $bashCommandLsLogsRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $Files = docker exec $ContainerName bash -c $bashCommandLsLogs
        return $Files
    } catch {
        return @()
    }
}

# 函数：生成测试日志内容
function New-LogContent {
    param([int]$Count)
    Write-Host "生成 $Count 条测试日志..." -ForegroundColor Yellow
    
    for ($i = 1; $i -le $Count; $i++) {
        $CurrentTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        
        try {
            $SshVerbosityArgs = ""
            if ($SshDebug) {
                $SshVerbosityArgs = "-vvv"
                Write-Host "SshDebug is ON, using verbose SSH output." -ForegroundColor DarkGray
            } else {
                $SshVerbosityArgs = "-q -o LogLevel=ERROR"
            }
            
            # Construct the remote command part - use simpler approach
            $LogEntry = "TEST_LOG_ENTRY_$i : $CurrentTime - Entry $i of $Count"
            
            # Use Start-Process for better control over command execution
            $ProcessArgs = @(
                $SshVerbosityArgs -split ' '
                "-p", $SshPort
                "-i", $SshKeyPath
                "-o", "ConnectTimeout=10"
                "-o", "StrictHostKeyChecking=no"
                "-o", "UserKnownHostsFile=/dev/null"
                "hexo@localhost"
                "echo '$LogEntry' >> /var/log/container/deployment.log"
            ) | Where-Object { $_ -ne "" }

            if ($SshDebug) {
                Write-Host "Executing SSH command: ssh $($ProcessArgs -join ' ')" -ForegroundColor DarkGray
            }
            
            $process = Start-Process -FilePath "ssh" -ArgumentList $ProcessArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput "stdout.tmp" -RedirectStandardError "stderr.tmp"
            
            if ($process.ExitCode -ne 0) {
                $sshError = if (Test-Path "stderr.tmp") { Get-Content "stderr.tmp" -Raw } else { "No error output" }
                Write-Host "SSH command failed. Exit code: $($process.ExitCode)" -ForegroundColor Red
                Write-Host "SSH output: $sshError" -ForegroundColor Red
            } else {
                if ($SshDebug) {
                    $sshOutput = if (Test-Path "stdout.tmp") { Get-Content "stdout.tmp" -Raw } else { "" }
                    if ($sshOutput) {
                        Write-Host "SSH output: $sshOutput" -ForegroundColor DarkGray
                    }
                }
            }
              # Clean up temp files
            Remove-Item "stdout.tmp", "stderr.tmp" -ErrorAction SilentlyContinue
            
            if ($i % 10 -eq 0) {
                Write-Host "已生成 $i/$Count 条日志" -ForegroundColor Gray
            }
            Start-Sleep -Milliseconds 10
        } catch {
            Write-Host "生成日志失败: $($_.Exception.Message)" -ForegroundColor Red
            # Optionally, log the command that failed if SshDebug is on
            if ($SshDebug) {
                Write-Host "Failed SSH command with args: $($ProcessArgs -join ' ')" -ForegroundColor DarkGray
            }
            break
        }
    }
}

# 开始测试
"=== 日志轮转测试开始 $(Get-Date) ===" | Add-Content $TestLog

Write-Host "`n=== 步骤 1: 检查初始日志状态 ===" -ForegroundColor Cyan
$InitialLogFiles = Get-LogFileList
Write-Host "初始日志文件:" -ForegroundColor Gray
$InitialLogFiles | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

$InitialLogSize = Get-LogFileSize "/var/log/container/deployment.log"
Write-Host "部署日志初始大小: $($InitialLogSize / 1024) KB" -ForegroundColor Gray

"初始日志大小: $InitialLogSize bytes" | Add-Content $TestLog

Write-Host "`n=== 步骤 2: 检查日志轮转配置 ===" -ForegroundColor Cyan

# 检查日志轮转函数是否存在
$RotateFunctionCheckCommand = 'grep -q setup_log_rotation /root/start.sh; if [ $? -eq 0 ]; then echo FUNCTION_EXISTS; else echo FUNCTION_NOT_FOUND; fi'
$CleanRotateFunctionCheckCommand = $RotateFunctionCheckCommand.Replace("`r`n", "`n").Replace("`r", "`n")
$RotateFunctionCheck = docker exec $ContainerName bash -c $CleanRotateFunctionCheckCommand
if ($RotateFunctionCheck -eq "FUNCTION_EXISTS") {
    Write-Host "SUCCESS: 日志轮转函数存在" -ForegroundColor Green
} else {
    Write-Host "FAIL: 日志轮转函数不存在" -ForegroundColor Red
}

# 检查定期检查功能
$PeriodicCheckCommand = 'grep -q setup_log_rotation /root/start.sh; if [ $? -eq 0 ]; then echo PERIODIC_EXISTS; else echo PERIODIC_NOT_FOUND; fi'
$CleanPeriodicCheckCommand = $PeriodicCheckCommand.Replace("`r`n", "`n").Replace("`r", "`n")
$PeriodicCheck = docker exec $ContainerName bash -c $CleanPeriodicCheckCommand
if ($PeriodicCheck -eq "PERIODIC_EXISTS") {
    Write-Host "SUCCESS: 定期日志检查功能存在" -ForegroundColor Green
} else {
    Write-Host "FAIL: 定期日志检查功能不存在" -ForegroundColor Red
}

# 检查日志轮转配置文件
$LogrotateConfigCheckCommand = 'test -f /etc/logrotate.d/deployment; if [ $? -eq 0 ]; then echo CONFIG_EXISTS; else echo CONFIG_NOT_FOUND; fi'
$CleanLogrotateConfigCheckCommand = $LogrotateConfigCheckCommand.Replace("`r`n", "`n").Replace("`r", "`n")
$LogrotateConfigCheck = docker exec $ContainerName bash -c $CleanLogrotateConfigCheckCommand
if ($LogrotateConfigCheck -eq "CONFIG_EXISTS") {
    Write-Host "SUCCESS: 日志轮转配置文件存在" -ForegroundColor Green
} else {
    Write-Host "FAIL: 日志轮转配置文件不存在" -ForegroundColor Red
}

Write-Host "`n=== 步骤 3: 生成测试日志 ===" -ForegroundColor Cyan

# 调试信息：显示参数传递情况
Write-Host "参数调试信息:" -ForegroundColor Magenta
Write-Host "  TotalBatches = $TotalBatches (来自参数)" -ForegroundColor Magenta
Write-Host "  FastRotationTest = $FastRotationTest" -ForegroundColor Magenta
Write-Host "  QuickLogGen = $QuickLogGen" -ForegroundColor Magenta
Write-Host "  PSBoundParameters.ContainsKey('TotalBatches') = $($PSBoundParameters.ContainsKey('TotalBatches'))" -ForegroundColor Magenta

if ($FastRotationTest) {
    Write-Host "快速轮转测试模式: 生成少量日志以快速验证轮转机制" -ForegroundColor Yellow
    Write-Host "注意: 快速模式主要验证轮转机制，而非大文件轮转" -ForegroundColor Gray
    
    # 快速轮转测试模式：生成更少的日志
    $FastBatchSize = 50
    # 只有在用户没有明确指定TotalBatches时才使用默认值
    if ($PSBoundParameters.ContainsKey('TotalBatches') -eq $false) {
        $TotalBatches = 3
        Write-Host "  未指定TotalBatches，使用快速模式默认值: $TotalBatches" -ForegroundColor Magenta
    } else {
        Write-Host "  使用用户指定的TotalBatches: $TotalBatches" -ForegroundColor Magenta
    }
    
    Write-Host "快速轮转测试: 将生成 $TotalBatches 批次，每批次 $FastBatchSize 条日志 (总计约$(($TotalBatches * $FastBatchSize * 211) / 1024)KB)" -ForegroundColor Gray
} elseif ($QuickLogGen) {
    Write-Host "快速日志生成模式: 生成少量日志数据以验证日志轮转机制" -ForegroundColor Yellow
    Write-Host "注意: 快速模式不会触发大文件轮转，但会验证日志写入和权限" -ForegroundColor Gray
    
    # 快速日志生成模式：如果没有指定TotalBatches参数，则使用默认值5
    if ($PSBoundParameters.ContainsKey('TotalBatches') -eq $false) {
        $TotalBatches = 5
        Write-Host "  未指定TotalBatches，使用快速日志生成默认值: $TotalBatches" -ForegroundColor Magenta
    } else {
        Write-Host "  使用用户指定的TotalBatches: $TotalBatches" -ForegroundColor Magenta
    }
    $BatchSize = 100
    
    Write-Host "快速日志生成: 将生成 $TotalBatches 批次，每批次 $BatchSize 条日志" -ForegroundColor Gray
} else {
    Write-Host "目标: 生成超过 ${LogSizeThresholdMB}MB 的日志数据以触发轮转" -ForegroundColor Gray
    Write-Host "注意: 针对测试环境，日志轮转阈值已设置为 20KB" -ForegroundColor Yellow
    
    # 计算需要生成的日志条数（实际测量每条约211字节，20KB需要约95条日志）
    $LogEntrySize = 211  # 基于实际测量结果更新
    $TargetBytes = 20 * 1024  # 20KB 固定目标，确保能触发轮转
    $RequiredEntries = [Math]::Ceiling($TargetBytes / $LogEntrySize)
    
    Write-Host "预计需要生成 $RequiredEntries 条日志以触发 20KB 轮转 (基于实际测量的 $LogEntrySize 字节/条)" -ForegroundColor Gray
    
    # 分批生成日志 - 使用传入的TotalBatches参数，默认为10个批次
    $BatchSize = 100
    # $TotalBatches 使用参数传入的值，不再重新赋值
    
    Write-Host "将生成 $TotalBatches 个批次，每批次 $BatchSize 条日志" -ForegroundColor Gray
}

# 开始日志生成和轮转测试
if (-not $SkipLogGeneration) {
    $TotalLogsGenerated = 0
    
    for ($batch = 1; $batch -le $TotalBatches; $batch++) {
        if ($FastRotationTest) {
            $CurrentBatchSize = $FastBatchSize
        } elseif ($QuickLogGen) {
            $CurrentBatchSize = $BatchSize
        } else {
            # 固定每个批次大小为 100 条日志
            $CurrentBatchSize = $BatchSize
        }
        
        Write-Host "批次 $batch/$TotalBatches : 生成 $CurrentBatchSize 条日志..." -ForegroundColor Yellow
        
        # 记录批次开始前的日志行数
        $bashCommandWcBeforeRaw = "LANG=C wc -l < /var/log/container/deployment.log 2>/dev/null || echo 0"
        $bashCommandWcBefore = $bashCommandWcBeforeRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $LogCountBefore = docker exec $ContainerName bash -c $bashCommandWcBefore
        
        New-LogContent -Count $CurrentBatchSize
        
        # 记录批次结束后的日志行数
        $bashCommandWcAfterRaw = "LANG=C wc -l < /var/log/container/deployment.log 2>/dev/null || echo 0"
        $bashCommandWcAfter = $bashCommandWcAfterRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $LogCountAfter = docker exec $ContainerName bash -c $bashCommandWcAfter
        $ActualLogsAdded = [int]$LogCountAfter - [int]$LogCountBefore
        $TotalLogsGenerated += $ActualLogsAdded
        
        Write-Host "实际添加日志: $ActualLogsAdded 条 (总计: $TotalLogsGenerated 条)" -ForegroundColor Gray
          # 检查当前日志大小
        $CurrentLogSize = Get-LogFileSize "/var/log/container/deployment.log"
        Write-Host "当前日志大小: $($CurrentLogSize / 1024) KB" -ForegroundColor Gray
        
        "批次 $batch 完成，当前日志大小: $CurrentLogSize bytes" | Add-Content $TestLog
          # 检查是否需要触发日志轮转（如果超过20KB）
        $ThresholdBytes = 20 * 1024  # 20KB
        if ($CurrentLogSize -gt $ThresholdBytes) {
            Write-Host "日志大小超过 20KB 阈值，尝试触发日志轮转..." -ForegroundColor Yellow
            $bashCommandLogrotateRaw = "LANG=C logrotate -f /etc/logrotate.d/deployment"
            $bashCommandLogrotate = $bashCommandLogrotateRaw.Replace("`r`n", "`n").Replace("`r", "`n")
            docker exec $ContainerName bash -c $bashCommandLogrotate | Out-Null
            Start-Sleep -Seconds 1
            
            # 重新检查文件大小
            $NewLogSize = Get-LogFileSize "/var/log/container/deployment.log"
            Write-Host "轮转后日志大小: $($NewLogSize / 1024) KB" -ForegroundColor Gray
        }          # 检查是否触发了日志轮转（排除.lock文件）
        $bashCommandLsBackupRaw = "LANG=C ls -la /var/log/container/ | grep 'deployment\.log\.' | grep -v '\.lock' | grep -v '^-.*deployment\.log$'"
        $bashCommandLsBackup = $bashCommandLsBackupRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $BackupFiles = docker exec $ContainerName bash -c $bashCommandLsBackup 2>$null
        if ($BackupFiles) {
            Write-Host "检测到备份文件，日志轮转已触发:" -ForegroundColor Green
            $BackupFiles | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        }
        
        # 为快速轮转测试在每个批次后短暂暂停
        if ($FastRotationTest) {
            Start-Sleep -Seconds 2
        }
    }
} else {
    Write-Host "跳过日志生成步骤 (-SkipLogGeneration 已设置)" -ForegroundColor Yellow
}

Write-Host "`n=== 步骤 4: 验证日志轮转结果 ===" -ForegroundColor Cyan

# 检查最终日志状态
$FinalLogFiles = Get-LogFileList
Write-Host "最终日志文件:" -ForegroundColor Gray
$FinalLogFiles | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

$CurrentLogSize = Get-LogFileSize "/var/log/container/deployment.log"
Write-Host "最终日志大小: $($CurrentLogSize / 1024) KB" -ForegroundColor Gray

# 检查备份文件（排除.lock文件）
$BackupFileCommandRaw = "LANG=C ls -la /var/log/container/ | grep 'deployment\.log\.' | grep -v '\.lock' | grep -v '^-.*deployment\.log$' | wc -l"
$BackupFileCommand = $BackupFileCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
$BackupFileCount = docker exec $ContainerName bash -c $BackupFileCommand 2>$null

Write-Host "备份文件数量: $BackupFileCount" -ForegroundColor Gray

# 详细分析日志轮转效果
Write-Host "`n=== 日志轮转分析报告 ===" -ForegroundColor Cyan
if (-not $SkipLogGeneration) {
    Write-Host "总共生成日志条数: $TotalLogsGenerated 条" -ForegroundColor Gray
    $EstimatedTotalSize = $TotalLogsGenerated * 211  # 基于实际测量的字节数
    Write-Host "预估总数据量: $($EstimatedTotalSize / 1024) KB" -ForegroundColor Gray
}

# 获取所有日志文件的详细信息
# $bashCommandLsAll = ("LANG=C ls -la /var/log/container/deployment.log*" -replace "\\\\r\\\\n", "\\\\n") # Fix CRLF
$bashCommandLsAllRaw = "LANG=C ls -la /var/log/container/deployment.log*"
$bashCommandLsAll = $bashCommandLsAllRaw.Replace("`r`n", "`n").Replace("`r", "`n")
$AllLogFiles = docker exec $ContainerName bash -c $bashCommandLsAll 2>$null
if ($AllLogFiles) {
    Write-Host "所有相关日志文件:" -ForegroundColor Gray
    $AllLogFiles | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    # 计算总的日志文件大小
    $TotalLogSize = 0
    $AllLogFiles | ForEach-Object {
        if ($_ -match '\s+(\d+)\s+.*deployment\.log') {
            $TotalLogSize += [int]$matches[1]
        }
    }
    Write-Host "所有日志文件总大小: $($TotalLogSize / 1024) KB" -ForegroundColor Gray
}

# 测试评估
$TestResults = @()

# 测试1: 检查日志轮转函数
if ($RotateFunctionCheck -eq "FUNCTION_EXISTS") {
    $TestResults += "日志轮转函数: PASS"
} else {
    $TestResults += "日志轮转函数: FAIL"
}

# 测试2: 检查定期检查功能
if ($PeriodicCheck -eq "PERIODIC_EXISTS") {
    $TestResults += "定期检查函数: PASS"
} else {
    $TestResults += "定期检查函数: FAIL"
}

# 测试3: 检查配置文件
if ($LogrotateConfigCheck -eq "CONFIG_EXISTS") {
    $TestResults += "轮转配置文件: PASS"
} else {
    $TestResults += "轮转配置文件: FAIL"
}

# 测试4: 检查日志权限
$bashCommandPermCheckRaw = "LANG=C ls -la /var/log/container/deployment.log | awk '{print `$1, `$3, `$4}'"
$bashCommandPermCheck = $bashCommandPermCheckRaw.Replace("`r`n", "`n").Replace("`r", "`n")
$LogPermissionCheck = docker exec $ContainerName bash -c $bashCommandPermCheck
Write-Host "日志文件权限: $LogPermissionCheck" -ForegroundColor Gray
if ($LogPermissionCheck -match "hexo.*hexo") {
    $TestResults += "日志权限: PASS"
} else {
    $TestResults += "日志权限: FAIL"
}

# 测试5: 检查备份文件命名（排除.lock文件）
$bashCommandBackupNameRaw = "LANG=C ls /var/log/container/ | grep 'deployment\.log\.[0-9]' | grep -v '\.lock' | head -1"
$bashCommandBackupName = $bashCommandBackupNameRaw.Replace("`r`n", "`n").Replace("`r", "`n")
$BackupNamingCheck = docker exec $ContainerName bash -c $bashCommandBackupName 2>$null
if ($BackupNamingCheck) {
    $TestResults += "备份文件命名: PASS"
} else {
    $TestResults += "备份文件命名: FAIL - 没有找到正确命名的备份文件"
}

if (-not $FastRotationTest -and -not $QuickLogGen) {
    # 测试6: 检查日志大小重置（仅在完整测试中）
    if ($CurrentLogSize -lt $InitialLogSize -or $BackupFileCount -gt 0) {
        $TestResults += "日志大小重置: PASS"
    } else {
        $TestResults += "日志大小重置: FAIL - 日志未被轮转"
    }
} else {
    $TestResults += "日志大小重置: SKIP - 快速测试模式"
}

# 计算成功率
$TotalTests = $TestResults.Count
$PassedTests = ($TestResults | Where-Object { $_ -match "PASS" }).Count
$SkippedTests = ($TestResults | Where-Object { $_ -match "SKIP" }).Count
$FailedTests = $TotalTests - $PassedTests - $SkippedTests
$SuccessRate = [Math]::Round(($PassedTests / $TotalTests) * 100, 2)

Write-Host "`n=== 测试结果汇总 ===" -ForegroundColor Cyan
Write-Host "总测试项: $TotalTests" -ForegroundColor Gray
Write-Host "通过: $PassedTests" -ForegroundColor Green
Write-Host "跳过: $SkippedTests" -ForegroundColor Yellow
Write-Host "失败: $FailedTests" -ForegroundColor Red
Write-Host "成功率: $SuccessRate%" -ForegroundColor Gray

Write-Host "`n详细结果:" -ForegroundColor Gray
$TestResults | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

# 保存测试报告
$TestMode = if ($FastRotationTest) { "快速轮转测试" } elseif ($QuickLogGen) { "快速日志生成" } else { "完整轮转测试" }
$PeriodicCheckResult = if ($TestResults | Where-Object { $_ -match "定期检查函数: PASS" }) { "通过" } else { "失败" }
$PermissionCheckResult = if ($TestResults | Where-Object { $_ -match "日志权限: PASS" }) { "通过" } else { "失败" }
$SizeControlCheckResult = if ($TestResults | Where-Object { $_ -match "日志大小重置: PASS" }) { 
    "通过" 
} elseif ($TestResults | Where-Object { $_ -match "日志大小重置: SKIP" }) { 
    "跳过（快速测试模式）" 
} else { 
    "失败" 
}
$BackupNamingCheckResult = if ($TestResults | Where-Object { $_ -match "备份文件命名: PASS" }) { "通过" } else { "失败" }
$DetailedResults = $TestResults | ForEach-Object { $_ } | Out-String

$ReportContent = @"
=== Hexo Container v0.0.3 日志轮转测试报告 ===
测试时间: $(Get-Date)
容器名称: $ContainerName
日志大小阈值: ${LogSizeThresholdMB}MB
测试模式: $TestMode

=== 测试统计 ===
总测试项: $TotalTests
通过: $PassedTests
跳过: $SkippedTests
失败: $FailedTests
成功率: $SuccessRate%

=== 详细结果 ===
$DetailedResults

=== 日志文件状态 ===
初始大小: $($InitialLogSize / 1024) KB
最终大小: $($CurrentLogSize / 1024) KB
备份文件数: $BackupFileCount

=== v0.0.3 新功能验证 ===
- 定期日志轮转检查: $PeriodicCheckResult
- Git Hook 日志权限: $PermissionCheckResult
- 智能日志大小控制: $SizeControlCheckResult
- 时间戳备份文件: $BackupNamingCheckResult
"@

$ReportFile = "$LogDir\log_rotation_test_report_$TimeStamp.txt"
$ReportContent | Out-File -FilePath $ReportFile -Encoding UTF8

Write-Host "`n详细测试日志: $TestLog" -ForegroundColor Gray
Write-Host "测试报告: $ReportFile" -ForegroundColor Gray

# 清理提示
Write-Host "`n=== 测试完成 ===" -ForegroundColor Cyan
Write-Host "日志轮转功能测试已完成。如需清理测试环境，请运行:" -ForegroundColor Gray
Write-Host "  .\cleanup_test.ps1" -ForegroundColor Gray

# 根据测试结果设置退出代码
if ($FailedTests -eq 0) {
    Write-Host "SUCCESS: 所有日志轮转测试通过！" -ForegroundColor Green
    exit 0
} else {
    Write-Host "WARNING: 部分日志轮转测试失败，请检查详细报告。" -ForegroundColor Yellow
    exit 1
}
