# Hexo Container v0.0.3 功能测试脚本 (Windows)
# functional_test.ps1

param(
    [string]$ContainerName = "hexo-test-v003",
    [int]$HttpPort = 8080, # Corrected port back to 8080 to match run_test.ps1
    [int]$SshPort = 2222,
    [string]$SshKeyPath = ".\\test_data\\ssh_keys\\test_key",
    [boolean]$SshDebug = $false # 新增 SshDebug 参数，默认为 false
)

# 确保脚本在正确的目录下执行
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# 确保 SSH 密钥路径为绝对路径
$SshKeyPath = Join-Path $ScriptDir "test_data\ssh_keys\test_key"

Write-Host "=== Hexo Container v0.0.3 功能测试 ===" -ForegroundColor Cyan

# 创建日志文件
$LogDir = ".\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# 如果这是独立运行的功能测试，清理旧的功能测试文件
if ($MyInvocation.ScriptName -eq $PSCommandPath) {
    Write-Host "=== 清理旧的功能测试文件 ===" -ForegroundColor Cyan
    $OldLogsDir = "$LogDir\old"
    if (-not (Test-Path $OldLogsDir)) {
        New-Item -ItemType Directory -Path $OldLogsDir -Force | Out-Null
        Write-Host "创建旧日志归档目录: $OldLogsDir" -ForegroundColor Gray
    }

    # 移动旧的功能测试文件到 old 文件夹
    $OldFunctionalFiles = Get-ChildItem $LogDir -File | Where-Object { 
        $_.Name -match "functional_test_.*\.(log|txt)$" 
    }

    if ($OldFunctionalFiles.Count -gt 0) {
        Write-Host "归档 $($OldFunctionalFiles.Count) 个旧功能测试文件到 old 文件夹..." -ForegroundColor Gray
        foreach ($file in $OldFunctionalFiles) {
            $destPath = Join-Path $OldLogsDir $file.Name
            Move-Item $file.FullName $destPath -Force
            Write-Host "  移动: $($file.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "没有旧的功能测试文件需要归档" -ForegroundColor Gray
    }
}

$TestLog = "$LogDir\functional_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$TestResults = @()

# 测试函数
function Test-Function {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$Description
    )
    
    Write-Host "`n=== $TestName ===" -ForegroundColor Yellow
    Write-Host "$Description" -ForegroundColor Gray
    
    $StartTime = Get-Date
    try {
        $Result = & $TestScript
        Write-Host "Debug: Test '$TestName', ScriptBlock returned: '$Result' (Type: $($Result.GetType().FullName))" -ForegroundColor Magenta # DEBUG LINE
        $EndTime = Get-Date
        $Duration = ($EndTime - $StartTime).TotalSeconds
        
        if ($Result) {
            Write-Host "✅ $TestName 通过 ($($Duration.ToString('F2'))s)" -ForegroundColor Green
            $Status = "PASS"
        } else {
            Write-Host "❌ $TestName 失败 ($($Duration.ToString('F2'))s)" -ForegroundColor Red
            $Status = "FAIL"
        }
    } catch {
        $EndTime = Get-Date
        $Duration = ($EndTime - $StartTime).TotalSeconds
        Write-Host "❌ $TestName 异常: $($_.Exception.Message) ($($Duration.ToString('F2'))s)" -ForegroundColor Red
        $Status = "ERROR"    }
    $Script:TestResults += [PSCustomObject]@{
        TestName = $TestName
        Status = $Status
        Duration = $Duration
        Timestamp = $StartTime
    }
    
    # 记录到日志文件
    "[$($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))] $TestName - $Status ($($Duration.ToString('F2'))s)" | Add-Content $TestLog
}

# 检查容器是否运行
Write-Host "检查容器状态..." -ForegroundColor Yellow
$ContainerRunning = docker ps --filter "name=$ContainerName" --format "{{.Names}}" | Select-String $ContainerName
if (-not $ContainerRunning) {
    Write-Host "❌ 容器 $ContainerName 未运行，请先运行 run_test.ps1" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 容器正在运行" -ForegroundColor Green

# 测试 1: HTTP 服务基础测试
Test-Function "HTTP服务基础测试" {
    try {
        $Response = Invoke-WebRequest -Uri "http://localhost:$HttpPort" -TimeoutSec 10
        return $Response.StatusCode -eq 200
    } catch {
        Write-Host "HTTP 请求失败: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} "测试主页是否可以正常访问"

# 测试 2: 健康检查端点测试
Test-Function "健康检查端点测试" {
    try {
        $Response = Invoke-WebRequest -Uri "http://localhost:$HttpPort/health" -TimeoutSec 5
        # 修复: 正确处理响应内容
        $Content = if ($Response.Content -is [byte[]]) { 
            [System.Text.Encoding]::UTF8.GetString($Response.Content).Trim() 
        } else { 
            $Response.Content.ToString().Trim() 
        }
        return $Response.StatusCode -eq 200 -and ($Content -eq "healthy" -or $Content -eq "OK")
    } catch {
        Write-Host "健康检查请求失败: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} "测试 /health 端点是否返回正确响应"

# 测试 3: SSH 服务连接测试
Test-Function "SSH服务连接测试" {
    if (-not (Test-Path $SshKeyPath)) {
        Write-Host "SSH 密钥不存在: $SshKeyPath" -ForegroundColor Red
        return $false
    }
    
    try {
        Write-Host "Attempting to remove [localhost]:$SshPort from known_hosts" -ForegroundColor DarkGray
        ssh-keygen -R "[localhost]:$SshPort" | Out-Null # Suppress normal output, errors will still show
        
        $SshRemoteCommand = "`"echo \'SSH_SUCCESS\'`""
        $SshVerbosityArgs = ""

        if ($SshDebug) {
            $SshVerbosityArgs = "-vvv"
            Write-Host "SshDebug is ON, using verbose SSH output for connection test." -ForegroundColor DarkGray
        } else {
            $SshVerbosityArgs = "-q -o LogLevel=ERROR"
        }
        
        $SshCommand = "ssh $SshVerbosityArgs -p $SshPort -i `"$SshKeyPath`" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null hexo@localhost $SshRemoteCommand"
        
        if ($SshDebug) { # Print command if debug is on
            Write-Host "Executing SSH command (Connection Test): $SshCommand" -ForegroundColor DarkGray
        }
        
        $SshOutput = Invoke-Expression $SshCommand 2>&1
        $CurrentExitCode = $LASTEXITCODE

        if ($SshDebug) {
            Write-Host "SSH command (Connection Test) executed. Exit code: $CurrentExitCode" -ForegroundColor DarkGray
            Write-Host "SSH output (raw):`n--BEGIN SSH OUTPUT--`n$SshOutput`n--END SSH OUTPUT--`n" -ForegroundColor DarkGray
        }

        if ($CurrentExitCode -ne 0) {
            Write-Host "SSH command failed with non-zero exit code: $CurrentExitCode." -ForegroundColor Red
            if (-not $SshDebug -and $SshOutput) { # 如果不是调试模式且有输出，则显示输出
                Write-Host "SSH output (Error):`n$SshOutput" -ForegroundColor DarkGray
            }
            return $false
        }

        if ($SshOutput -match "SSH_SUCCESS") {
            Write-Host "SSH command successful (exit code 0) and output matched \'SSH_SUCCESS\'." -ForegroundColor Green
            return $true
        } else {
            Write-Host "SSH command succeeded (exit code 0), but output did not contain \'SSH_SUCCESS\'." -ForegroundColor Red
            if (-not $SshDebug -and $SshOutput) { # 如果不是调试模式且有输出，则显示输出
                Write-Host "SSH output (Unexpected):`n$SshOutput" -ForegroundColor DarkGray
            }
            return $false
        }
    } catch {
        Write-Host "SSH 连接测试中发生异常: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} "测试 SSH 服务是否可以正常连接"

# 测试 4: Git 仓库初始化测试
Test-Function "Git仓库初始化测试" {
    try {
        $GitCommandRaw = "test -d /home/hexo/hexo.git && echo 'GIT_REPO_EXISTS'"
        $GitCommand = $GitCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $GitOutput = docker exec $ContainerName bash -c $GitCommand 2>$null
        
        return ($GitOutput -match "GIT_REPO_EXISTS") # Changed to -match
    } catch {
        Write-Host "Git 仓库检查失败: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} "检查 Git 裸仓库是否正确初始化"

# 测试 5: 部署钩子测试
Test-Function "部署钩子测试" {
    try {
        $HookCommandRaw = "test -f /home/hexo/hexo.git/hooks/post-receive && echo 'HOOK_EXISTS'"
        $HookCommand = $HookCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $HookOutput = docker exec $ContainerName bash -c $HookCommand 2>$null
        if ($HookOutput -match "HOOK_EXISTS") { # Changed to -match
            # 检查钩子是否可执行
            $HookExecCommandRaw = "test -x /home/hexo/hexo.git/hooks/post-receive && echo 'HOOK_EXECUTABLE'"
            $HookExecCommand = $HookExecCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
            $HookExecOutput = docker exec $ContainerName bash -c $HookExecCommand 2>$null
            return ($HookExecOutput -match "HOOK_EXECUTABLE") # Changed to -match
        }
        return $false
    } catch {
        Write-Host "部署钩子检查失败: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} "检查 Git post-receive 钩子是否正确配置"

# 测试 6: 文件权限测试
Test-Function "文件权限测试" {
    try {
        # 检查 hexo 用户权限
        $PermCommandRaw = "su - hexo -c 'whoami'"
        $PermCommand = $PermCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $PermOutput = docker exec $ContainerName bash -c $PermCommand 2>$null
        if ($PermOutput -match "hexo") { # Changed to -match
            # 检查网站目录权限
            $WebDirCommandRaw = "su - hexo -c 'test -w /home/www/hexo && echo WRITABLE'"
            $WebDirCommand = $WebDirCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
            $WebDirOutput = docker exec $ContainerName bash -c $WebDirCommand 2>$null
            return ($WebDirOutput -match "WRITABLE") # Changed to -match
        }
        return $false
    } catch {
        Write-Host "权限检查失败: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} "检查用户权限和目录访问权限"

# 测试 7: 日志文件权限测试 (v0.0.3 新功能)
Test-Function "日志文件权限测试" {
    try {
        # 检查日志文件是否存在且属于 hexo 用户
        $LogFileCheckCommandRaw = "LANG=C ls -la /var/log/container/deployment.log"
        $LogFileCheckCommand = $LogFileCheckCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $LogFileCheck = docker exec $ContainerName bash -c $LogFileCheckCommand 2>$null
        if ($LogFileCheck -match "hexo.*hexo") {
            # 测试 hexo 用户是否可以写入日志
            $WriteTestCommandRaw = "su - hexo -c 'echo TEST_WRITE >> /var/log/container/deployment.log && echo WRITE_SUCCESS'"
            $WriteTestCommand = $WriteTestCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
            $WriteTest = docker exec $ContainerName bash -c $WriteTestCommand 2>$null
            return ($WriteTest -match "WRITE_SUCCESS") # Changed to -match
        }
        Write-Host "日志文件权限检查失败: 文件不属于 hexo 用户" -ForegroundColor Red
        return $false
    } catch {
        Write-Host "日志权限检查失败: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} "测试 hexo 用户对部署日志文件的写入权限 (v0.0.3 新功能)"

# 测试 8: 模拟 Git 部署测试
Test-Function "模拟Git部署测试" {
    if (-not (Test-Path $SshKeyPath)) {
        Write-Host "SSH 密钥不存在，跳过部署测试" -ForegroundColor Yellow
        return $false # Return false to indicate test did not pass
    }
    
    try {
        Write-Host "Attempting to remove [localhost]:$SshPort from known_hosts for Git test" -ForegroundColor DarkGray
        ssh-keygen -R "[localhost]:$SshPort" | Out-Null # Suppress normal output, errors will still show
        
        $GitDeployRemoteCommand = "`"cd /home/hexo/hexo.git && git --git-dir=. --work-tree=/home/www/hexo status && echo \'GIT_DEPLOY_SUCCESS\'`""
        $SshVerbosityArgsGit = ""

        if ($SshDebug) {
            $SshVerbosityArgsGit = "-vvv"
            Write-Host "SshDebug is ON, using verbose SSH output for Git deploy test." -ForegroundColor DarkGray
        } else {
            $SshVerbosityArgsGit = "-q -o LogLevel=ERROR"
        }
        
        $GitDeployCommand = "ssh $SshVerbosityArgsGit -p $SshPort -i `"$SshKeyPath`" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null hexo@localhost $GitDeployRemoteCommand"

        if ($SshDebug) { # Print command if debug is on
            Write-Host "Executing SSH (Git Deploy) command (Debug): $GitDeployCommand" -ForegroundColor DarkGray
        }
        
        $GitDeployOutput = Invoke-Expression $GitDeployCommand 2>&1
        $CurrentExitCode = $LASTEXITCODE

        if ($SshDebug) {
            Write-Host "SSH (Git Deploy) command executed. Exit code: $CurrentExitCode" -ForegroundColor DarkGray
            Write-Host "SSH (Git Deploy) output (raw):`n--BEGIN GIT DEPLOY SSH OUTPUT--`n$GitDeployOutput`n--END GIT DEPLOY SSH OUTPUT--`n" -ForegroundColor DarkGray
        }

        if ($CurrentExitCode -ne 0) {
            Write-Host "SSH (Git Deploy) command failed with non-zero exit code: $CurrentExitCode." -ForegroundColor Red
            if (-not $SshDebug -and $GitDeployOutput) {
                Write-Host "SSH (Git Deploy) output (Error):`n$GitDeployOutput" -ForegroundColor DarkGray
            }
            return $false
        }

        if (-not ($GitDeployOutput -match "GIT_DEPLOY_SUCCESS")) {
            Write-Host "SSH (Git Deploy) command succeeded (exit code 0), but did not output \'GIT_DEPLOY_SUCCESS\'." -ForegroundColor Red
            if (-not $SshDebug -and $GitDeployOutput) {
                Write-Host "SSH (Git Deploy) output (Unexpected):`n$GitDeployOutput" -ForegroundColor DarkGray
            }
            return $false
        }
            
        Start-Sleep -Seconds 2 # Give time for log to be written if deployment was triggered
        $LogCheckCommandRaw = "test -f /var/log/container/deployment.log && echo \'LOG_EXISTS\'"
        $LogCheckCommand = $LogCheckCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $LogOutput = docker exec $ContainerName bash -c $LogCheckCommand 2>$null
        
        if ($LogOutput -match "LOG_EXISTS") {
            Write-Host "SSH (Git Deploy) successful and deployment log found." -ForegroundColor Green
            return $true
        } else {
            Write-Host "SSH (Git Deploy) successful, but deployment log \'/var/log/container/deployment.log\' not found." -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "模拟 Git 部署测试中发生异常: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} "模拟 Git 推送部署并检查日志生成"

# 测试 9: 日志轮转功能测试 (v0.0.3 新功能)
Test-Function "日志轮转功能测试" {
    try {
        # 检查日志轮转函数是否存在
        $RotateOutputCommandRaw = "grep -q 'setup_log_rotation' /root/start.sh && echo 'SCRIPT_EXISTS'"
        $RotateOutputCommand = $RotateOutputCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
        $RotateOutput = docker exec $ContainerName bash -c $RotateOutputCommand 2>$null
        if ($RotateOutput -match "SCRIPT_EXISTS") { # Changed to -match
            # 检查 logrotate 配置文件是否存在
            $LogrotateOutputCommandRaw = "test -f /etc/logrotate.d/deployment && echo 'LOGROTATE_CONFIG_EXISTS'"
            $LogrotateOutputCommand = $LogrotateOutputCommandRaw.Replace("`r`n", "`n").Replace("`r", "`n")
            $LogrotateOutput = docker exec $ContainerName bash -c $LogrotateOutputCommand 2>$null
            return ($LogrotateOutput -match "LOGROTATE_CONFIG_EXISTS") # Changed to -match
        }
        return $false
    } catch {
        Write-Host "日志轮转检查失败: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} "检查日志轮转功能是否正确配置 (v0.0.3 新功能)"

# 测试 10: 容器资源使用测试
Test-Function "容器资源使用测试" {
    try {
        $Stats = docker stats $ContainerName --no-stream --format "table {{.MemUsage}}\t{{.CPUPerc}}" | Select-Object -Skip 1
        if ($Stats) {
            Write-Host "资源使用情况: $Stats" -ForegroundColor Gray
            # 简单检查：如果能获取到统计信息就认为通过
            return $true
        }
        return $false
    } catch {
        Write-Host "资源统计获取失败: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} "检查容器资源使用情况"

# 生成测试报告
Write-Host "`n=== 测试总结报告 ===" -ForegroundColor Cyan

$PassedTests = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count
$FailedTests = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
$ErrorTests = ($TestResults | Where-Object { $_.Status -eq "ERROR" }).Count
$TotalTests = $TestResults.Count

Write-Host "总测试数: $TotalTests" -ForegroundColor White
Write-Host "通过: $PassedTests" -ForegroundColor Green
Write-Host "失败: $FailedTests" -ForegroundColor Red
Write-Host "错误: $ErrorTests" -ForegroundColor Yellow

$SuccessRate = if ($TotalTests -gt 0) { ($PassedTests / $TotalTests * 100).ToString("F1") } else { "0.0" }
Write-Host "成功率: $SuccessRate%" -ForegroundColor $(if ($PassedTests -eq $TotalTests) { "Green" } else { "Yellow" })

# 详细测试结果表格
Write-Host "`n=== 详细测试结果 ===" -ForegroundColor Cyan
$TestResults | Format-Table -Property TestName, Status, Duration, Timestamp -AutoSize

# 失败的测试详情
$FailedTestList = $TestResults | Where-Object { $_.Status -ne "PASS" }
if ($FailedTestList) {
    Write-Host "`n=== 失败的测试 ===" -ForegroundColor Red
    $FailedTestList | ForEach-Object {
        Write-Host "❌ $($_.TestName) - $($_.Status)" -ForegroundColor Red
    }
}

# 保存详细报告到文件
$ReportContent = @"
=== Hexo Container v0.0.3 功能测试报告 ===
测试时间: $(Get-Date)
容器名称: $ContainerName
HTTP 端口: $HttpPort
SSH 端口: $SshPort

=== 测试统计 ===
总测试数: $TotalTests
通过: $PassedTests
失败: $FailedTests
错误: $ErrorTests
成功率: $SuccessRate%

=== 详细结果 ===
$($TestResults | ForEach-Object { "$($_.TestName): $($_.Status) ($($_.Duration.ToString('F2'))s)" } | Out-String)

=== v0.0.3 新功能测试状态 ===
日志文件权限测试: $($TestResults | Where-Object { $_.TestName -eq "日志文件权限测试" } | Select-Object -ExpandProperty Status)
日志轮转功能测试: $($TestResults | Where-Object { $_.TestName -eq "日志轮转功能测试" } | Select-Object -ExpandProperty Status)
"@

$ReportFile = "$LogDir\\functional_test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt" # Corrected date format and added .txt extension

# 如果测试是从 run_test.ps1 调用的，则退出状态码将由 run_test.ps1 处理
# 如果是独立运行，则根据测试结果设置退出代码
if ($MyInvocation.ScriptName -eq $PSCommandPath) {
    if ($FailedTests -gt 0 -or $ErrorTests -gt 0) {
        exit 1
    } else {
        exit 0
    }
}
