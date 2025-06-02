# Docker Hexo Static Blog v0.0.3 - 完整测试指南

> **📅 最新更新**: 2025年5月30日 - 所有 Windows 和 Linux 测试脚本已完成路径修正，现在支持从任意目录执行，具有更好的可移植性和稳定性。Linux 平台同步实现了与 Windows 平台相同的路径修正改进。

## 概述

本测试指南提供了基于实际测试脚本框架的完整测试流程，支持两个测试平台：
- **Windows 11 + Docker Desktop** (使用 PowerShell 测试套件)
- **N305 NAS + Linux Docker** (使用 Bash 测试套件)

## v0.0.3 版本主要新特性

本版本重点改进了日志管理和权限控制：
- ✅ **定期日志轮转功能** - 每30分钟自动检查日志大小
- ✅ **修复 Git Hook 日志权限** - 确保 hexo 用户可以写入部署日志
- ✅ **增强的日志管理** - 智能备份和旧日志清理
- ✅ **改进的错误处理** - 更详细的日志记录和错误恢复
- ✅ **权限动态管理** - 自动修复容器内文件权限问题

## 测试环境要求

### 测试环境要求

### Windows 11 测试环境
- **操作系统**: Windows 11 专业版或企业版
- **Docker**: Docker Desktop 4.15+ (支持 Linux 容器)
- **PowerShell**: PowerShell 5.1+ 或 PowerShell Core 7+
- **内存**: 至少 4GB 可用内存
- **磁盘**: 至少 10GB 可用磁盘空间
- **网络**: 端口 8888 和 2222 可用 (默认端口已更新)
- **权限**: 管理员权限或 Docker 使用权限

> **端口更新**: 默认 HTTP 端口已从 8080 更新为 8888，避免常见的端口冲突

### N305 NAS Linux 测试环境
- **操作系统**: Linux (Ubuntu 20.04+, Debian 11+, 或兼容系统)
- **Docker**: Docker Engine 20.10+
- **Shell**: Bash 4.0+
- **内存**: 至少 2GB 可用内存
- **磁盘**: 至少 5GB 可用磁盘空间
- **权限**: SSH 访问权限和 sudo 权限

## 自动化测试框架

本项目提供了完整的自动化测试框架，包含以下测试脚本：

### Windows PowerShell 测试套件
位置：`test/v0.0.3/windows/`

- **start.ps1** - 完整测试套件启动脚本，支持一键测试
- **build_test.ps1** - Docker 镜像构建测试
- **run_test.ps1** - 容器运行和基础功能测试
- **functional_test.ps1** - HTTP/SSH/健康检查等功能测试
- **log_rotation_test.ps1** - v0.0.3 新增的日志轮转功能测试
- **cleanup_test.ps1** - 测试环境清理
- **test_paths.ps1** - 路径验证工具脚本（新增）
- **README.md** - 详细使用说明文档（新增）
- **PATH_FIXES_REPORT.md** - 路径修正报告（新增）

> **重要更新**: 所有 Windows 测试脚本已完成路径修正，现在支持从任意目录执行，并确保所有文件操作在正确的测试目录内进行。

#### 路径修正改进
- ✅ **工作目录自动切换**: 所有脚本现在自动切换到脚本所在目录
- ✅ **相对路径标准化**: Dockerfile 路径、日志目录、测试数据目录统一使用相对路径
- ✅ **PowerShell 语法修正**: param() 块位置已修正，确保参数正确传递
- ✅ **卷挂载路径修正**: Docker 卷挂载使用正确的绝对路径
- ✅ **SSH 密钥路径统一**: 所有测试中的 SSH 密钥路径已统一

### Linux Bash 测试套件
位置：`test/v0.0.3/linux/`

- **start.sh** - 完整测试套件启动脚本，支持一键测试
- **build_test.sh** - Docker 镜像构建测试
- **run_test.sh** - 容器运行和基础功能测试
- **functional_test.sh** - HTTP/SSH/健康检查等功能测试
- **log_rotation_test.sh** - v0.0.3 新增的日志轮转功能测试
- **cleanup_test.sh** - 测试环境清理
- **test_paths.sh** - 路径验证和环境检查工具 (新增)
- **README.md** - Linux 测试套件详细使用说明 (新增)
- **PATH_FIXES_REPORT.md** - 路径修正完成报告 (新增)

#### 路径修正改进 (Linux)
- ✅ **脚本目录自动获取**: 所有脚本现在使用 `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
- ✅ **工作目录自动切换**: 通过 `cd "$SCRIPT_DIR"` 确保工作目录一致
- ✅ **相对路径标准化**: Dockerfile 路径、日志目录、测试数据目录统一使用相对路径
- ✅ **卷挂载路径修正**: Docker 卷挂载使用正确的绝对路径
- ✅ **SSH 密钥路径统一**: 所有测试中的 SSH 密钥路径已统一
- ✅ **日志目录本地化**: 从 `/tmp` 迁移到脚本本地目录
- ✅ **端口配置更新**: HTTP 端口从 8080 更新为 8888

## 快速开始

### Windows 环境一键测试

```powershell
# 方式1: 从测试目录运行 (推荐)
cd "c:\Users\Unbal\Desktop\dockerfiledir\test\v0.0.3\windows"
.\start.ps1

# 方式2: 从任意目录运行 (路径修正后支持)
& "c:\Users\Unbal\Desktop\dockerfiledir\test\v0.0.3\windows\start.ps1"

# 或使用自定义参数
.\start.ps1 -Tag "hexo-test:v0.0.3" -HttpPort 8888 -SshPort 2222

# 验证路径配置 (新增功能)
.\test_paths.ps1
```

### Linux 环境一键测试

```bash
# 方式1: 从测试目录运行 (推荐)
cd "/path/to/dockerfiledir/test/v0.0.3/linux"

# 设置执行权限
chmod +x *.sh

# 运行完整测试套件
./start.sh

# 方式2: 从任意目录运行 (路径修正后支持)
"/path/to/dockerfiledir/test/v0.0.3/linux/start.sh"

# 或使用自定义参数
./start.sh --clean-start

# 验证路径配置 (新增功能)
./test_paths.sh
```

## Windows 11 Docker Desktop 测试

### 方法一：一键自动化测试（推荐）

使用完整的自动化测试套件，包含构建、运行、功能验证、日志轮转测试等：

```powershell
# 方式1: 从测试目录运行 (推荐)
cd "c:\Users\Unbal\Desktop\dockerfiledir\test\v0.0.3\windows"
.\start.ps1

# 方式2: 从任意目录运行 (路径修正后支持)
& "c:\Users\Unbal\Desktop\dockerfiledir\test\v0.0.3\windows\start.ps1"

# 使用自定义参数运行测试
.\start.ps1 -Tag "hexo-test:v0.0.3" -HttpPort 8888 -SshPort 2222

# 运行测试后自动清理
.\start.ps1 -CleanupAfter

# 跳过某些测试阶段
.\start.ps1 -SkipBuild -SkipLogRotation

# 验证路径配置 (新增)
.\test_paths.ps1
```

### 方法二：分步测试

如果需要分步执行或调试特定功能，可以单独运行各个测试脚本：

#### 1. 构建测试 (build_test.ps1)
```powershell
# 基础构建测试
.\build_test.ps1

# 使用自定义参数构建
.\build_test.ps1 -Tag "my-hexo:test" -Platform "linux/amd64"

# 注意：脚本现在会自动切换到正确目录，确保 Dockerfile 路径正确
```

#### 2. 运行测试 (run_test.ps1)
```powershell
# 基础运行测试
.\run_test.ps1

# 使用自定义参数 (默认端口已更新为 8888)
.\run_test.ps1 -Tag "my-hexo:test" -HttpPort 8888 -SshPort 2222 -ContainerName "my-hexo-test"

# 注意：卷挂载路径已修正，使用正确的绝对路径
```

#### 3. 功能测试 (functional_test.ps1)
```powershell
# 完整功能测试：HTTP、SSH、健康检查
.\functional_test.ps1

# 测试指定容器 (默认端口已更新)
.\functional_test.ps1 -ContainerName "my-hexo-test" -HttpPort 8888 -SshPort 2222

# 注意：SSH 密钥路径已统一，自动使用正确的绝对路径
```

#### 4. 日志轮转测试 (log_rotation_test.ps1) - v0.0.3 新功能
```powershell
# 测试日志轮转功能
.\log_rotation_test.ps1

# 测试指定容器的日志轮转
.\log_rotation_test.ps1 -ContainerName "my-hexo-test"

# 注意：SSH 密钥路径已修正，确保测试的稳定性和可移植性
```

#### 5. 清理测试 (cleanup_test.ps1)
```powershell
# 清理测试环境
.\cleanup_test.ps1

# 清理指定容器和镜像
.\cleanup_test.ps1 -ContainerName "my-hexo-test" -ImageTag "my-hexo:test"
```

### start.ps1 完整参数说明

```powershell
# 完整参数列表
.\start.ps1 `
    -SkipBuild          # 跳过构建阶段
    -SkipFunctional     # 跳过功能测试阶段
    -SkipLogRotation    # 跳过日志轮转测试阶段
    -CleanupAfter       # 测试完成后自动清理环境
    -Tag "custom:tag"   # 自定义 Docker 镜像标签
    -ContainerName "name" # 自定义容器名称
    -HttpPort 8888      # HTTP 服务端口 (默认: 8888)
    -SshPort 2222       # SSH 服务端口 (默认: 2222)

# 测试结果和日志
# 所有测试都会生成详细的日志文件在 logs/ 目录下
# 测试完成后会显示完整的测试报告

# 路径验证工具 (新增)
.\test_paths.ps1        # 验证和创建所需的目录结构

# 详细使用说明
Get-Content .\README.md # 查看详细的使用说明和故障排除指南
```

## N305 NAS Linux 测试

### 方法一：一键自动化测试（推荐）

使用完整的自动化测试套件，支持完全自动化的测试流程：

```bash
# 进入 Linux 测试目录
cd "/path/to/dockerfiledir/test/v0.0.3/linux"

# 设置执行权限
chmod +x *.sh

# 运行完整测试套件（推荐）
./start.sh

# 使用清理模式运行测试（运行前清理环境）
./start.sh --clean-start

# 查看帮助信息
./start.sh --help
```

### 方法二：分步测试

如果需要分步执行或调试特定功能，可以单独运行各个测试脚本：

#### 1. 构建测试 (build_test.sh)
```bash
# 基础构建测试
./build_test.sh

# 使用自定义参数构建
./build_test.sh "my-hexo:test" "linux/amd64"
```

#### 2. 运行测试 (run_test.sh)
```bash
# 基础运行测试
./run_test.sh

# 使用自定义参数
./run_test.sh "my-hexo:test" "my-hexo-test" 8888 2222
```

#### 3. 功能测试 (functional_test.sh)
```bash
# 完整功能测试：HTTP、SSH、健康检查
./functional_test.sh

# 测试指定容器
./functional_test.sh "my-hexo-test" 8888 2222
```

#### 4. 日志轮转测试 (log_rotation_test.sh) - v0.0.3 新功能
```bash
# 测试日志轮转功能
./log_rotation_test.sh

# 测试指定容器的日志轮转
./log_rotation_test.sh "my-hexo-test"
```

#### 5. 清理测试 (cleanup_test.sh)
```bash
# 清理测试环境
./cleanup_test.sh

# 清理指定容器和镜像
./cleanup_test.sh "my-hexo-test" "my-hexo:test"
```

### start.sh 完整参数说明

```bash
# 基础用法
./start.sh                    # 标准测试流程
./start.sh --clean-start      # 清理后重新开始测试
./start.sh --help            # 显示帮助信息

# 测试结果和日志
# 所有测试日志保存在 /tmp/hexo-test-suite/ 目录下
# 测试完成后会显示完整的彩色测试报告
# 支持自动故障检测和详细错误报告
```

### Linux 环境特殊配置

```bash
# 确保 Docker 服务运行
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户添加到 docker 组（避免使用 sudo）
sudo usermod -aG docker $USER
newgrp docker

# 验证 Docker 安装
docker --version
docker-compose --version

# 确保所需端口可用
sudo netstat -tlnp | grep -E ':(8888|2222)'
```

## 自动化测试框架特性

### 测试套件功能
1. **智能测试流程** - 自动检测前置条件，智能跳过不必要的步骤
2. **详细日志记录** - 每个测试阶段都有完整的日志记录和时间戳
3. **彩色输出显示** - 清晰的成功/失败状态指示
4. **错误自动诊断** - 测试失败时提供详细的错误分析
5. **性能指标统计** - 自动记录构建时间、启动时间、内存使用等
6. **测试报告生成** - 自动生成标准化的测试报告

### 测试覆盖范围
- ✅ **Docker 镜像构建** - 验证 Dockerfile_v0.0.3 构建过程
- ✅ **容器启动验证** - 检查容器是否正常启动和运行
- ✅ **HTTP 服务测试** - 验证 Nginx 服务和静态文件服务
- ✅ **SSH 服务测试** - 验证 SSH 连接和身份验证
- ✅ **健康检查测试** - 验证 /health 端点响应
- ✅ **日志轮转测试** - v0.0.3 特有的日志管理功能
- ✅ **Git 部署测试** - 验证 Git hooks 和自动部署
- ✅ **权限验证测试** - 确保文件权限和用户权限正确
- ✅ **环境清理测试** - 验证测试环境的完整清理

## 测试检查清单

### 基础功能验证
- [ ] Docker 镜像成功构建（< 5 分钟）
- [ ] 容器成功启动（< 30 秒）
- [ ] HTTP 服务响应正常（端口 8888）
- [ ] 健康检查端点 `/health` 返回 "OK"
- [ ] SSH 服务可连接（端口 22/2222）
- [ ] Git 仓库初始化正确
- [ ] Hexo 站点文件部署正常

### v0.0.3 新功能验证
- [ ] 定期日志轮转功能正常（每30分钟检查）
- [ ] Git Hook 日志权限正确（hexo 用户可写入）
- [ ] 部署日志 `/var/log/container/deployment.log` 正常
- [ ] 日志文件大小控制（10MB 轮转触发）
- [ ] 旧日志文件自动清理和备份
- [ ] 时间戳日志备份文件生成

### 安全性验证
- [ ] 容器以非 root 用户（hexo）运行
- [ ] SSH 仅支持密钥认证（密码认证已禁用）
- [ ] 文件权限设置正确（644/755）
- [ ] 网络端口访问控制正常
- [ ] 敏感文件权限保护

### 性能和稳定性验证
- [ ] 容器启动时间 < 30 秒
- [ ] HTTP 响应时间 < 1 秒
- [ ] 内存使用 < 500MB
- [ ] CPU 使用率正常（< 50%）
- [ ] 日志轮转不影响服务性能
- [ ] 多次部署操作稳定无错误

## 故障排查指南

### 自动化测试框架故障排查

#### 1. 测试脚本权限问题
```bash
# Linux 环境
chmod +x test/v0.0.3/linux/*.sh

# Windows 环境（PowerShell 执行策略）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### 2. 路径相关问题 (新增)
```powershell
# Windows 环境 - 验证路径配置
cd "c:\Users\Unbal\Desktop\dockerfiledir\test\v0.0.3\windows"
.\test_paths.ps1

# 查看路径修正报告
Get-Content .\PATH_FIXES_REPORT.md

# 查看详细使用说明
Get-Content .\README.md
```

#### 2. Docker 相关问题
```bash
# 检查 Docker 服务状态
docker info
docker version

# 清理 Docker 环境
docker system prune -f
docker volume prune -f
```

#### 3. 端口冲突问题
```bash
# Linux 检查端口占用
netstat -tlnp | grep -E ':(8888|2222)'  # 端口已更新
sudo lsof -i :8888
sudo lsof -i :2222

# Windows 检查端口占用
netstat -ano | findstr :8888            # 端口已更新
netstat -ano | findstr :2222
```

#### 4. 测试日志分析
```bash
# 查看最新测试日志
ls -la logs/ | tail -5                    # Linux
Get-ChildItem logs\ | Sort-Object LastWriteTime | Select-Object -Last 5  # Windows

# 搜索错误信息
grep -i error logs/test_suite_*.log       # Linux
Select-String -Pattern "error" -Path "logs\test_suite_*.log"  # Windows
```

### 容器运行时故障排查

#### 1. 容器无法启动
```bash
# 检查容器日志
docker logs hexo-test-v003

# 检查镜像是否存在
docker images | grep hexo-test

# 检查 Dockerfile 语法
docker build --dry-run -f Dockerfile_v0.0.3 .
```

#### 2. 服务连接失败
```bash
# 检查容器网络
docker port hexo-test-v003
docker inspect hexo-test-v003 | grep -A 10 "NetworkSettings"

# 测试容器内服务
docker exec hexo-test-v003 curl -f http://localhost/health
docker exec hexo-test-v003 netstat -tlnp
```

#### 3. 日志轮转问题（v0.0.3 特有）
```bash
# 检查日志轮转配置
docker exec hexo-test-v003 cat /etc/logrotate.d/container-logs

# 手动触发日志轮转
docker exec hexo-test-v003 logrotate -f /etc/logrotate.d/container-logs

# 检查日志文件状态
docker exec hexo-test-v003 ls -la /var/log/container/
```

## 测试报告模板

### 基本信息
- **测试版本**: Docker Hexo Static Blog v0.0.3
- **测试平台**: Windows 11 / Linux
- **测试日期**: {{ 测试日期 }}
- **测试人员**: {{ 测试人员 }}
- **Docker 版本**: {{ docker --version }}

### 自动化测试结果
| 测试阶段 | 状态 | 执行时间 | 备注 |
|----------|------|----------|------|
| 镜像构建 | ✅/❌ | {{ 时间 }} | {{ 备注 }} |
| 容器启动 | ✅/❌ | {{ 时间 }} | {{ 备注 }} |
| HTTP 服务 | ✅/❌ | {{ 时间 }} | {{ 备注 }} |
| SSH 服务 | ✅/❌ | {{ 时间 }} | {{ 备注 }} |
| 功能测试 | ✅/❌ | {{ 时间 }} | {{ 备注 }} |
| 日志轮转 | ✅/❌ | {{ 时间 }} | {{ 备注 }} |
| 环境清理 | ✅/❌ | {{ 时间 }} | {{ 备注 }} |

### 性能指标
- **总测试时间**: {{ 总时间 }}
- **镜像构建时间**: {{ 构建时间 }}
- **容器启动时间**: {{ 启动时间 }}
- **内存使用峰值**: {{ 内存使用 }}
- **HTTP 响应时间**: {{ 响应时间 }}

### v0.0.3 新功能测试结果
- **日志轮转功能**: ✅/❌ {{ 详细说明 }}
- **Git Hook 权限**: ✅/❌ {{ 详细说明 }}
- **部署日志管理**: ✅/❌ {{ 详细说明 }}
- **权限动态修复**: ✅/❌ {{ 详细说明 }}

### 发现的问题
1. {{ 问题描述 1 }}
2. {{ 问题描述 2 }}
3. {{ 问题描述 3 }}

### 改进建议
1. {{ 改进建议 1 }}
2. {{ 改进建议 2 }}
3. {{ 改进建议 3 }}

---

## 总结

本测试指南基于项目中实际的自动化测试框架编写，提供了：

### 主要特性
- ✅ **完全自动化** - 一键执行完整测试流程
- ✅ **跨平台支持** - Windows PowerShell 和 Linux Bash 双平台
- ✅ **智能诊断** - 自动错误检测和详细报告
- ✅ **详细日志** - 完整的测试过程记录
- ✅ **灵活配置** - 支持自定义参数和选择性测试
- ✅ **路径修正完成** - 所有 Windows 和 Linux 测试脚本已完成路径修正 (2025年5月)

### v0.0.3 测试脚本更新内容 (2025年5月30日)
#### Windows PowerShell 测试套件改进
1. **路径修正**: 所有 Windows PowerShell 测试脚本完成路径修正
2. **工作目录标准化**: 脚本自动切换到正确的工作目录
3. **PowerShell 语法修正**: param() 块位置已修正
4. **卷挂载路径修正**: Docker 卷挂载使用正确的绝对路径
5. **SSH 密钥路径统一**: 统一所有测试中的 SSH 密钥路径处理
6. **端口更新**: 默认 HTTP 端口从 8080 更新为 8888
7. **新增工具**: 添加 `test_paths.ps1` 路径验证工具

#### Linux Bash 测试套件改进 (新增)
1. **路径修正**: 所有 Linux Bash 测试脚本完成路径修正
2. **脚本目录自动获取**: 使用 `SCRIPT_DIR` 变量统一路径处理
3. **工作目录标准化**: 通过 `cd "$SCRIPT_DIR"` 确保一致性
4. **卷挂载路径修正**: Docker 卷挂载使用正确的绝对路径
5. **SSH 密钥路径统一**: 统一所有测试中的 SSH 密钥路径处理
6. **日志目录本地化**: 从 `/tmp` 迁移到脚本本地目录
7. **端口配置更新**: HTTP 端口从 8080 更新为 8888
8. **新增工具**: 添加 `test_paths.sh` 路径验证工具和详细文档
7. **新增工具脚本**: 
   - `test_paths.ps1` - 路径验证工具
   - `README.md` - 详细使用说明
   - `PATH_FIXES_REPORT.md` - 路径修正完成报告

### 使用建议
1. **日常开发测试** - 使用一键测试脚本快速验证
2. **详细功能验证** - 使用分步测试脚本深入调试
3. **持续集成** - 集成到 CI/CD 流程中自动化验证
4. **生产部署前** - 运行完整测试套件确保稳定性
5. **路径验证** - 使用 `test_paths.ps1` 验证测试环境配置

### 测试覆盖
本测试框架全面覆盖了 Docker Hexo Static Blog v0.0.3 的所有核心功能，特别是新版本的日志轮转和权限管理功能，确保在不同环境中的稳定性和可靠性。

通过使用这个自动化测试框架，可以大大提高测试效率，减少人为错误，并确保每次测试的一致性和完整性。经过路径修正后，Windows 测试脚本现在具有更好的可移植性和可靠性。
