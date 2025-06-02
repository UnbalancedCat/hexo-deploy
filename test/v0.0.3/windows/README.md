# Hexo Container v0.0.3 测试脚本使用说明 (含日志轮转功能)

本指南详细说明了如何使用针对 Hexo Container v0.0.3 (已验证稳定版) 的 PowerShell 测试脚本套件。

## v0.0.3 版本核心特性与测试说明

### 🚀 日志轮转功能 (Log Rotation)
v0.0.3 版本新增了自动日志轮转功能，包括：
- **智能大小检测** - 当 `deployment.log` 文件达到 1MB 时自动轮转
- **自动备份** - 保留最近 5 个轮转文件 (例如 `deployment.log.1.gz`, `deployment.log.2.gz` 等)
- **压缩存储** - 自动压缩旧日志文件 (如 `.gz` 格式) 节省空间
- **权限管理** - 确保 hexo 用户可正常写入日志及轮转操作
- **测试优化** - 相关测试脚本经过优化，可快速验证此功能

### 📊 测试脚本优化成果 (针对 v0.0.3 测试流程)
- **成功率提升** - 测试脚本的整体执行成功率得到提升
- **测试速度** - 日志轮转等测试的验证速度加快
- **阈值优化** - 日志轮转阈值在测试中调整为 1MB，以加速验证过程
- **快速验证** - `log_rotation_test.ps1` 脚本提供快速测试模式，生成少量日志即可验证核心轮转机制

## 路径修正说明

本次更新修正了 `test/v0.0.3/windows` 目录下所有测试脚本的路径问题，确保脚本能够：

1. **正确调用对应文件** - 无论从哪个目录执行脚本
2. **正确生成文件** - 所有生成的文件都保存在测试目录及其子目录中
3. **使用相对路径** - 提高脚本的可移植性

## 修正的关键问题

### 1. 脚本工作目录统一
- 所有脚本现在都会自动切换到脚本所在目录作为工作目录
- 使用 `$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path` 获取脚本目录
- 使用 `Set-Location $ScriptDir` 设置工作目录

### 2. PowerShell param 块位置修正
- 将 `param()` 块移动到脚本最开始
- 确保脚本可以正确接收参数

### 3. 路径引用修正
- **Dockerfile 路径**: `../../../Dockerfile_v0.0.3` (相对于测试脚本目录)
- **日志目录**: `./logs` (在测试脚本目录下)
- **测试数据**: `./test_data` (在测试脚本目录下)
- **SSH 密钥**: `./test_data/ssh_keys/test_key`

### 4. Docker 卷挂载路径修正
- 使用 `$ScriptDir` 构建绝对路径进行卷挂载
- 确保容器能正确访问主机文件

## 文件结构

```
test/v0.0.3/windows/
├── build_test.ps1          # 构建测试脚本
├── run_test.ps1            # 运行测试脚本
├── functional_test.ps1     # 功能测试脚本
├── log_rotation_test.ps1   # 🆕 日志轮转测试脚本 (v0.0.3核心新功能)
├── test_log_size_reset.ps1 # 🆕 日志大小重置专项测试脚本 (容器重启修复验证)
├── cleanup_test.ps1        # 清理测试脚本
├── start.ps1              # 一键测试套件
├── test_paths.ps1         # 路径验证脚本
├── logs/                  # 测试日志目录 (自动创建)
└── test_data/            # 测试数据目录 (自动创建)
    ├── hexo_site/        # 测试站点文件
    └── ssh_keys/         # SSH 密钥文件
```

## 🆕 日志轮转测试详解

### log_rotation_test.ps1 参数
- `-FastRotationTest`: 快速轮转测试 (3批次×50条日志，约3KB)
- `-QuickLogGen`: 快速日志生成 (5批次×100条日志，约100KB)
- `-LogSizeThresholdMB`: 日志大小阈值(MB) (默认: 1)
- `-ContainerName`: 容器名称 (默认: hexo-test-v003)

### test_log_size_reset.ps1 参数 (🆕 容器重启修复验证)
- `-ContainerName`: 容器名称 (默认: hexo-test-v003)
- `-SshPort`: SSH端口 (默认: 2222)
- `-TargetSizeKB`: 目标日志大小(KB) (默认: 25KB，超过20KB阈值)
- `-Verbose`: 详细输出模式

此脚本专门验证容器重启时的日志监控修复功能，确保：
- 容器重启后不会重复输出旧的Git部署信息
- 日志位置跟踪文件正确工作
- 部署日志监控在重启后正常恢复

### 测试模式说明
1. **FastRotationTest** - 验证轮转机制，生成少量日志快速验证
2. **QuickLogGen** - 测试日志写入和权限，生成中等量日志
3. **默认模式** - 完整测试，生成足够日志触发实际轮转

### 使用示例
```powershell
# 快速验证日志轮转机制 (推荐，仅需2分钟)
.\log_rotation_test.ps1 -FastRotationTest

# 测试日志写入功能
.\log_rotation_test.ps1 -QuickLogGen

# 完整日志轮转测试
.\log_rotation_test.ps1

# 自定义日志大小阈值
.\log_rotation_test.ps1 -LogSizeThresholdMB 2

# 🆕 容器重启修复验证测试
.\test_log_size_reset.ps1

# 详细模式运行重启修复测试
.\test_log_size_reset.ps1 -Verbose

# 自定义目标大小测试
.\test_log_size_reset.ps1 -TargetSizeKB 30
```

### 测试报告
每次测试都会生成详细报告：
- **执行日志**: `./logs/log_rotation_test_YYYYMMDD_HHMMSS.log`
- **测试报告**: `./logs/log_rotation_test_report_YYYYMMDD_HHMMSS.txt`

## 使用方式

### 方式1: 从测试目录运行 (推荐)
```powershell
cd "c:\Users\Unbal\Desktop\dockerfiledir\test\v0.0.3\windows"
.\start.ps1
```

### 方式2: 从任意目录运行
```powershell
& "c:\Users\Unbal\Desktop\dockerfiledir\test\v0.0.3\windows\start.ps1"
```

### 方式3: 单独运行各个测试
```powershell
cd "c:\Users\Unbal\Desktop\dockerfiledir\test\v0.0.3\windows"
.\build_test.ps1                # 构建镜像
.\run_test.ps1                  # 启动容器
.\functional_test.ps1           # 功能测试
.\log_rotation_test.ps1         # 日志轮转测试
.\cleanup_test.ps1              # 清理环境
```

## 测试参数

### start.ps1 参数
- `-SkipBuild`: 跳过构建阶段
- `-SkipFunctional`: 跳过功能测试
- `-SkipLogRotation`: 跳过日志轮转测试
- `-CleanupAfter`: 测试后自动清理
- `-Tag`: 镜像标签 (默认: hexo-test:v0.0.3)
- `-ContainerName`: 容器名称 (默认: hexo-test-v003)
- `-HttpPort`: HTTP端口 (默认: 8080)
- `-SshPort`: SSH端口 (默认: 2222)

### 使用示例
```powershell
# 完整测试 (包含构建和清理)
.\start.ps1 -CleanupAfter

# 跳过构建，只测试功能
.\start.ps1 -SkipBuild

# 自定义端口
.\start.ps1 -HttpPort 9999 -SshPort 3333
```

## 验证路径配置

运行路径验证脚本检查配置：
```powershell
.\test_paths.ps1
```

此脚本会检查所有关键路径是否正确，并自动创建必需的目录。

## 注意事项

1. **权限要求**: 需要管理员权限运行 Docker 命令
2. **端口冲突**: 确保指定的端口 (如 8080, 2222) 未被占用
3. **SSH 密钥**: 测试脚本 (`run_test.ps1`) 会优先尝试从用户 `~/.ssh/` 目录或测试子目录 `test_data/ssh_keys/` 中使用现有的 `test_key` (或 `id_rsa`)。如果找不到这些密钥，脚本会自动生成新的密钥对用于测试，并存放于 `test_data/ssh_keys/`。
4. **Docker 环境**: 确保 Docker Desktop 正在运行
5. **日志清理**: `cleanup_test.ps1` 或 `start.ps1 -CleanupAfter` 会清理测试容器和镜像。测试脚本自身产生的日志默认保留在 `logs` 目录下。

## 故障排除

### 权限错误
```powershell
# 以管理员身份运行 PowerShell
Start-Process powershell -Verb RunAs
```

### 路径不存在错误
```powershell
# 运行路径验证
.\test_paths.ps1
```

### Docker 连接错误
```powershell
# 检查 Docker 状态
docker version 
```

### 端口占用错误
```powershell
# 查看端口占用
netstat -ano | findstr :8080
```
