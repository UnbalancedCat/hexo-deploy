# Hexo Container v0.0.3 完整测试套件 (Windows)
# start.ps1 - 一键启动所有测试

param(
    [switch]$SkipBuild = $false,
    [switch]$SkipFunctional = $false,
    [switch]$SkipLogRotation = $false,
    [switch]$SkipLogGeneration = $false,
    [switch]$QuickLogGen = $false,
    [switch]$FastRotationTest = $false,
    [switch]$CleanupAfter = $false,
    [switch]$SshDebug = $false, # 新增: 控制SSH详细输出
    [string]$Tag = "hexo-container:v0.0.3",
    [string]$ContainerName = "hexo-test-v003",
    [int]$HttpPort = 8080,
    [int]$SshPort = 2222
)

# 确保脚本在正确的目录下执行
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "=== Hexo Container v0.0.3 完整测试套件 ===" -ForegroundColor Cyan
Write-Host "这个脚本将执行完整的 v0.0.3 测试流程" -ForegroundColor Gray

# 创建日志目录
$LogDir = ".\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# 智能清理和归档旧日志文件
Write-Host "=== 智能清理和归档旧日志文件 ===" -ForegroundColor Cyan
$OldLogsDir = "$LogDir\old"
if (-not (Test-Path $OldLogsDir)) {
    New-Item -ItemType Directory -Path $OldLogsDir -Force | Out-Null
    Write-Host "创建旧日志归档目录: $OldLogsDir" -ForegroundColor Gray
}

# 检查 deployment.log 文件的智能管理
function Test-DeploymentLogCompatibility {
    param(
        [string]$DeploymentLogPath,
        [bool]$QuickLogGen,
        [bool]$SkipLogGeneration,
        [bool]$FastRotationTest
    )
    
    if (-not (Test-Path $DeploymentLogPath)) {
        return $false
    }
    
    try {
        # 检查文件大小来判断日志类型
        $fileSize = (Get-Item $DeploymentLogPath).Length
        $fileSizeKB = [math]::Round($fileSize / 1024, 2)
        
        Write-Host "检测到现有 deployment.log，大小: $fileSizeKB KB" -ForegroundColor Gray
        
        # 根据文件大小判断日志类型
        # 快速轮转测试: 通常 2-5KB (3批次 * 15条 = 45条日志)
        # 快速模式: 通常 10-100KB (5批次 * 100条 = 500条日志)
        # 正常模式: 通常 > 500KB (525批次 * 100条 = 52500条日志)
        # 跳过模式: 通常很小 < 10KB (只有系统日志)
        
        if ($SkipLogGeneration) {
            # 跳过日志生成模式，任何现有文件都可以保留
            Write-Host "跳过日志生成模式：保留现有 deployment.log" -ForegroundColor Green
            return $true
        } elseif ($FastRotationTest) {
            # 快速轮转测试模式，检查是否已经是轮转测试的结果
            if ($fileSizeKB -ge 2 -and $fileSizeKB -le 10) {
                Write-Host "检测到快速轮转测试模式的现有文件，保留使用" -ForegroundColor Green
                return $true
            } else {
                Write-Host "现有文件不符合快速轮转测试模式要求，需要重新生成" -ForegroundColor Yellow
                return $false
            }
        } elseif ($QuickLogGen) {
            # 快速日志生成模式，检查是否已经是快速模式的结果
            if ($fileSizeKB -ge 10 -and $fileSizeKB -le 100) {
                Write-Host "检测到快速日志生成模式的现有文件，保留使用" -ForegroundColor Green
                return $true
            } else {
                Write-Host "现有文件不符合快速日志生成模式要求，需要重新生成" -ForegroundColor Yellow
                return $false
            }
        } else {
            # 正常模式，检查是否已经是正常模式的结果
            if ($fileSizeKB -ge 300) {
                Write-Host "检测到正常模式的现有文件，保留使用" -ForegroundColor Green
                return $true
            } else {
                Write-Host "现有文件不符合正常模式要求，需要重新生成" -ForegroundColor Yellow
                return $false
            }
        }
    } catch {
        Write-Host "检查 deployment.log 兼容性时出错: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# 检查 deployment.log 是否需要处理
$DeploymentLogPath = "$LogDir\deployment.log"
$KeepDeploymentLog = Test-DeploymentLogCompatibility -DeploymentLogPath $DeploymentLogPath -QuickLogGen $QuickLogGen -SkipLogGeneration $SkipLogGeneration -FastRotationTest $FastRotationTest

# 移动旧的日志和报告文件到 old 文件夹 (排除符合条件的 deployment.log)
$OldLogFiles = Get-ChildItem $LogDir -File | Where-Object { 
    ($_.Extension -eq ".log" -or $_.Extension -eq ".txt") -and 
    -not ($_.Name -eq "deployment.log" -and $KeepDeploymentLog)
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

# 智能处理容器内的 deployment.log
Write-Host "智能处理容器内的 deployment.log..." -ForegroundColor Gray
try {
    # 检查容器是否存在并运行
    $ContainerStatus = docker ps -f "name=$ContainerName" --format "table {{.Names}}\t{{.Status}}" 2>$null
    if ($ContainerStatus -match $ContainerName) {
        if (-not $KeepDeploymentLog) {
            Write-Host "发现运行中的容器，清空 deployment.log..." -ForegroundColor Gray
            docker exec $ContainerName sh -c "echo '' > /var/log/container/deployment.log" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "deployment.log 已清空，将重新生成" -ForegroundColor Green
            } else {
                Write-Host "清空 deployment.log 失败，容器可能没有运行" -ForegroundColor Yellow
            }
        } else {
            Write-Host "保留现有的 deployment.log，跳过清空操作" -ForegroundColor Green
        }
    } else {
        Write-Host "容器未运行，将在容器启动时处理 deployment.log" -ForegroundColor Yellow
    }
} catch {
    Write-Host "处理 deployment.log 时出错: $($_.Exception.Message)" -ForegroundColor Yellow
}

$TestSuiteLog = "$LogDir\test_suite_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$TestResults = @()

# 记录测试结果的函数
function Add-TestResult {
    param($Phase, $Status, $Duration, $Message = "")
    $script:TestResults += [PSCustomObject]@{
        Phase = $Phase
        Status = $Status
        Duration = $Duration
        Message = $Message
        Timestamp = Get-Date
    }
      $LogEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Phase : $Status ($($Duration.ToString('F2'))s) $Message"
    Write-Host $LogEntry -ForegroundColor Gray
    $LogEntry | Add-Content $TestSuiteLog -Encoding UTF8
}

Write-Host "`n测试配置:" -ForegroundColor Yellow
Write-Host "镜像标签: $Tag" -ForegroundColor Gray
Write-Host "容器名称: $ContainerName" -ForegroundColor Gray
Write-Host "HTTP 端口: $HttpPort" -ForegroundColor Gray
Write-Host "SSH 端口: $SshPort" -ForegroundColor Gray
Write-Host "跳过构建: $SkipBuild" -ForegroundColor Gray
Write-Host "跳过功能测试: $SkipFunctional" -ForegroundColor Gray
Write-Host "跳过日志轮转测试: $SkipLogRotation" -ForegroundColor Gray
Write-Host "跳过日志数据生成: $SkipLogGeneration" -ForegroundColor Gray
Write-Host "快速日志生成模式: $QuickLogGen" -ForegroundColor Gray
Write-Host "快速轮转测试模式: $FastRotationTest" -ForegroundColor Gray
Write-Host "测试后清理: $CleanupAfter" -ForegroundColor Gray
Write-Host "SSH 详细输出: $SshDebug" -ForegroundColor Gray # 新增: 显示SSH Debug状态

# 阶段 1: 构建测试
if (-not $SkipBuild) {
    Write-Host "`n=== 阶段 1: 构建镜像 ===" -ForegroundColor Cyan
    $BuildStart = Get-Date
    
    try {
        $BuildResult = & ".\build_test.ps1" -Tag $Tag
        $BuildEnd = Get-Date
        $BuildDuration = ($BuildEnd - $BuildStart).TotalSeconds
          if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] 构建阶段完成" -ForegroundColor Green
            Add-TestResult "构建镜像" "SUCCESS" $BuildDuration
        } else {
            Write-Host "[FAIL] 构建阶段失败" -ForegroundColor Red
            Add-TestResult "构建镜像" "FAIL" $BuildDuration
            Write-Host "测试中止：构建失败" -ForegroundColor Red
            exit 1
        }
    } catch {
        $BuildEnd = Get-Date
        $BuildDuration = ($BuildEnd - $BuildStart).TotalSeconds
        Write-Host "[ERROR] 构建阶段异常: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult "构建镜像" "ERROR" $BuildDuration $_.Exception.Message
        exit 1
    }
} else {
    Write-Host "[SKIP] 跳过构建阶段" -ForegroundColor Yellow
    Add-TestResult "构建镜像" "SKIPPED" 0
}

# 阶段 2: 启动容器
Write-Host "`n=== 阶段 2: 启动容器 ===" -ForegroundColor Cyan
$RunStart = Get-Date

try {
    $RunResult = & ".\run_test.ps1" -Tag $Tag -ContainerName $ContainerName -HttpPort $HttpPort -SshPort $SshPort
    $RunEnd = Get-Date
    $RunDuration = ($RunEnd - $RunStart).TotalSeconds
      if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] 容器启动完成" -ForegroundColor Green
        Add-TestResult "启动容器" "SUCCESS" $RunDuration
    } else {
        Write-Host "[FAIL] 容器启动失败" -ForegroundColor Red
        Add-TestResult "启动容器" "FAIL" $RunDuration
        Write-Host "测试中止：容器启动失败" -ForegroundColor Red
        exit 1
    }
} catch {
    $RunEnd = Get-Date
    $RunDuration = ($RunEnd - $RunStart).TotalSeconds
    Write-Host "[ERROR] 容器启动异常: $($_.Exception.Message)" -ForegroundColor Red
    Add-TestResult "启动容器" "ERROR" $RunDuration $_.Exception.Message
    exit 1
}

# 等待容器完全就绪
Write-Host "`n等待容器服务就绪..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# 阶段 3: 功能测试
if (-not $SkipFunctional) {
    Write-Host "`n=== 阶段 3: 功能测试 ===" -ForegroundColor Cyan
    $FuncStart = Get-Date
    
    try {
        $FuncResult = & ".\\functional_test.ps1" -ContainerName $ContainerName -HttpPort $HttpPort -SshPort $SshPort -SshDebug:$SshDebug # 修改: 传递 $SshDebug
        $FuncEnd = Get-Date
        $FuncDuration = ($FuncEnd - $FuncStart).TotalSeconds
          if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] 功能测试完成" -ForegroundColor Green
            Add-TestResult "功能测试" "SUCCESS" $FuncDuration
        } else {
            Write-Host "[FAIL] 功能测试失败" -ForegroundColor Red
            Add-TestResult "功能测试" "FAIL" $FuncDuration
        }
    } catch {
        $FuncEnd = Get-Date
        $FuncDuration = ($FuncEnd - $FuncStart).TotalSeconds
        Write-Host "[ERROR] 功能测试异常: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult "功能测试" "ERROR" $FuncDuration $_.Exception.Message
    }
} else {
    Write-Host "[SKIP] 跳过功能测试阶段" -ForegroundColor Yellow
    Add-TestResult "功能测试" "SKIPPED" 0
}

# 阶段 4: 日志轮转测试 (v0.0.3 新功能)
if (-not $SkipLogRotation) {
    Write-Host "`n=== 阶段 4: 日志轮转测试 (v0.0.3 新功能) ===" -ForegroundColor Cyan
    $LogStart = Get-Date
    try {
        # 调用日志轮转测试脚本，并传递 -CalledFromTestSuite 参数
        $LogResult = & ".\\log_rotation_test.ps1" -ContainerName $ContainerName -HttpPort $HttpPort -SshPort $SshPort -FastRotationTest:$FastRotationTest -QuickLogGen:$QuickLogGen -SkipLogGeneration:$SkipLogGeneration -CalledFromTestSuite:$true -SshDebug:$SshDebug # 修改: 传递 $SshDebug
        $LogEnd = Get-Date
        $LogDuration = ($LogEnd - $LogStart).TotalSeconds
          if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] 日志轮转测试完成" -ForegroundColor Green
            Add-TestResult "日志轮转测试" "SUCCESS" $LogDuration
        } else {
            Write-Host "[FAIL] 日志轮转测试失败" -ForegroundColor Red
            Add-TestResult "日志轮转测试" "FAIL" $LogDuration
        }
    } catch {
        $LogEnd = Get-Date
        $LogDuration = ($LogEnd - $LogStart).TotalSeconds
        Write-Host "[ERROR] 日志轮转测试异常: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult "日志轮转测试" "ERROR" $LogDuration $_.Exception.Message
    }
} else {
    Write-Host "[SKIP] 跳过日志轮转测试阶段" -ForegroundColor Yellow
    Add-TestResult "日志轮转测试" "SKIPPED" 0
}

# 阶段 5: 清理 (可选)
if ($CleanupAfter) {
    Write-Host "`n=== 阶段 5: 测试后清理 ===" -ForegroundColor Cyan
    $CleanStart = Get-Date
      try {
        $CleanResult = & ".\cleanup_test.ps1" -ContainerName $ContainerName -ImageTag $Tag -Force -Interactive:$false
        $CleanEnd = Get-Date
        $CleanDuration = ($CleanEnd - $CleanStart).TotalSeconds
          if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] 清理完成" -ForegroundColor Green
            Add-TestResult "测试后清理" "SUCCESS" $CleanDuration
        } else {
            Write-Host "[FAIL] 清理失败" -ForegroundColor Red
            Add-TestResult "测试后清理" "FAIL" $CleanDuration
        }
    } catch {
        $CleanEnd = Get-Date
        $CleanDuration = ($CleanEnd - $CleanStart).TotalSeconds
        Write-Host "[ERROR] 清理异常: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult "测试后清理" "ERROR" $CleanDuration $_.Exception.Message
    }
} else {
    Write-Host "[SKIP] 跳过清理阶段 (容器保持运行)" -ForegroundColor Yellow
    Add-TestResult "测试后清理" "SKIPPED" 0
}

# 生成完整测试报告
Write-Host "`n=== Hexo Container v0.0.3 完整测试报告 ===" -ForegroundColor Cyan

$SuccessCount = ($TestResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
$FailCount = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
$ErrorCount = ($TestResults | Where-Object { $_.Status -eq "ERROR" }).Count
$SkippedCount = ($TestResults | Where-Object { $_.Status -eq "SKIPPED" }).Count
$TotalPhases = $TestResults.Count

$TotalDuration = ($TestResults | Where-Object { $_.Status -ne "SKIPPED" } | Measure-Object -Property Duration -Sum).Sum

Write-Host "`n=== 测试统计 ===" -ForegroundColor White
Write-Host "总阶段数: $TotalPhases" -ForegroundColor White
Write-Host "成功: $SuccessCount" -ForegroundColor Green
Write-Host "失败: $FailCount" -ForegroundColor Red
Write-Host "错误: $ErrorCount" -ForegroundColor Yellow
Write-Host "跳过: $SkippedCount" -ForegroundColor Gray

$SuccessRate = if (($TotalPhases - $SkippedCount) -gt 0) { 
    ($SuccessCount / ($TotalPhases - $SkippedCount) * 100).ToString("F1") 
} else { 
    "0.0" 
}
Write-Host "成功率: $SuccessRate%" -ForegroundColor $(if ($FailCount -eq 0 -and $ErrorCount -eq 0) { "Green" } else { "Yellow" })
Write-Host "总耗时: $($TotalDuration.ToString('F2')) 秒" -ForegroundColor Gray

# 详细阶段结果
Write-Host "`n=== 详细阶段结果 ===" -ForegroundColor White
$TestResults | Format-Table -Property Phase, Status, @{Name="Duration(s)"; Expression={$_.Duration.ToString("F2")}}, Timestamp -AutoSize

# v0.0.3 新功能测试摘要
Write-Host "`n=== v0.0.3 新功能测试摘要 ===" -ForegroundColor Cyan
$LogRotationResult = $TestResults | Where-Object { $_.Phase -eq "日志轮转测试" }
if ($LogRotationResult) {
    $Status = $LogRotationResult.Status
    $StatusColor = switch ($Status) {
        "SUCCESS" { "Green" }
        "FAIL" { "Red" }
        "ERROR" { "Yellow" }
        "SKIPPED" { "Gray" }
    }
    Write-Host "日志轮转功能: $Status" -ForegroundColor $StatusColor
} else {
    Write-Host "日志轮转功能: 未测试" -ForegroundColor Gray
}

# 失败阶段详情
$FailedPhases = $TestResults | Where-Object { $_.Status -eq "FAIL" -or $_.Status -eq "ERROR" }
if ($FailedPhases) {
    Write-Host "`n=== 失败阶段详情 ===" -ForegroundColor Red
    $FailedPhases | ForEach-Object {
        Write-Host "[FAIL] $($_.Phase): $($_.Status)" -ForegroundColor Red
        if ($_.Message) {
            Write-Host "   错误信息: $($_.Message)" -ForegroundColor Gray
        }
    }
}

# 保存完整报告
$ReportContent = @"
=== Hexo Container v0.0.3 完整测试套件报告 ===
测试时间: $(Get-Date)
测试配置:
  镜像标签: $Tag
  容器名称: $ContainerName
  HTTP 端口: $HttpPort
  SSH 端口: $SshPort
  SSH 详细输出: $SshDebug # 新增

=== 测试统计 ===
总阶段数: $TotalPhases
成功: $SuccessCount
失败: $FailCount
错误: $ErrorCount
跳过: $SkippedCount
成功率: $SuccessRate%
总耗时: $($TotalDuration.ToString('F2')) 秒

=== 详细结果 ===
$($TestResults | ForEach-Object { "$($_.Timestamp.ToString('HH:mm:ss')) - $($_.Phase): $($_.Status) ($($_.Duration.ToString('F2'))s) $($_.Message)" } | Out-String)

=== v0.0.3 新功能验证 ===
日志轮转测试: $(if ($LogRotationResult) { $LogRotationResult.Status } else { "未执行" })

=== 建议 ===
$(if ($FailCount -eq 0 -and $ErrorCount -eq 0) {
    "[SUCCESS] 所有测试阶段成功完成！Hexo Container v0.0.3 可以投入使用。"
} else {
    "[WARNING] 部分测试阶段失败，建议检查详细日志并修复问题后重新测试。"
})

测试完成。如需重新测试，请运行相应的测试脚本。
"@

$FinalReportFile = "$LogDir\test_suite_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$ReportContent | Out-File -FilePath $FinalReportFile -Encoding UTF8

Write-Host "`n完整测试日志: $TestSuiteLog" -ForegroundColor Gray
Write-Host "完整测试报告: $FinalReportFile" -ForegroundColor Gray

# 后续建议
Write-Host "`n=== 后续操作建议 ===" -ForegroundColor Cyan
if (-not $CleanupAfter) {
    Write-Host "容器当前正在运行，可以通过以下方式访问：" -ForegroundColor Gray
    Write-Host "  浏览器访问: http://localhost:$HttpPort" -ForegroundColor Gray
    Write-Host "  健康检查: http://localhost:$HttpPort/health" -ForegroundColor Gray
    Write-Host "  SSH 连接: ssh -p $SshPort -i test_data\ssh_keys\test_key hexo@localhost" -ForegroundColor Gray
    Write-Host "`n清理测试环境: .\cleanup_test.ps1" -ForegroundColor Gray
}

Write-Host "`n重新运行特定测试：" -ForegroundColor Gray
Write-Host "  .\functional_test.ps1                      # 仅功能测试" -ForegroundColor Gray
Write-Host "  .\log_rotation_test.ps1                    # 仅日志轮转测试" -ForegroundColor Gray
Write-Host "  .\log_rotation_test.ps1 -FastRotationTest  # 快速轮转测试（含备份验证）" -ForegroundColor Gray
Write-Host "  .\log_rotation_test.ps1 -SkipLogGeneration # 跳过大量日志生成的轮转测试" -ForegroundColor Gray

Write-Host "`n启动选项说明：" -ForegroundColor Gray
Write-Host "  -FastRotationTest       # 快速轮转测试模式（降低阈值，验证完整轮转功能）" -ForegroundColor Gray
Write-Host "  -QuickLogGen           # 快速日志生成模式（不触发轮转，仅验证日志写入）" -ForegroundColor Gray
Write-Host "  -SkipLogGeneration     # 跳过大量日志数据生成（加快测试速度）" -ForegroundColor Gray
Write-Host "  -SkipBuild             # 跳过Docker镜像构建" -ForegroundColor Gray
Write-Host "  -SkipFunctional        # 跳过功能测试" -ForegroundColor Gray
Write-Host "  -SkipLogRotation       # 跳过日志轮转测试" -ForegroundColor Gray
Write-Host "  -CleanupAfter          # 测试完成后自动清理" -ForegroundColor Gray
Write-Host "  -SshDebug              # 启用SSH详细输出模式" -ForegroundColor Gray # 新增

Write-Host "`n=== 测试套件完成 ===" -ForegroundColor Cyan

# 根据结果设置退出代码
if ($FailCount -eq 0 -and $ErrorCount -eq 0) {
    Write-Host "[SUCCESS] 完整测试套件成功完成！" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[WARNING] 测试套件中有失败项目，请检查详细报告。" -ForegroundColor Yellow
    exit 1
}
