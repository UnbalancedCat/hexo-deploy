# Hexo Container v0.0.3 测试脚本使用说明 (Linux)

## 路径修正说明

本次更新修正了 `test/v0.0.3/linux` 目录下所有测试脚本的路径问题，确保脚本能够：

1. **正确调用对应文件** - 无论从哪个目录执行脚本
2. **正确生成文件** - 所有生成的文件都保存在测试目录及其子目录中
3. **使用相对路径** - 提高脚本的可移植性

## 修正的关键问题

### 1. 脚本工作目录统一
- 所有脚本现在都会自动切换到脚本所在目录作为工作目录
- 使用 `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` 获取脚本目录
- 使用 `cd "$SCRIPT_DIR"` 设置工作目录

### 2. 路径引用修正
- **Dockerfile 路径**: `../../../Dockerfile_v0.0.3` (相对于测试脚本目录)
- **日志目录**: `$SCRIPT_DIR/logs` (在测试脚本目录下)
- **测试数据**: `$SCRIPT_DIR/test_data` (在测试脚本目录下)
- **SSH 密钥**: `$SCRIPT_DIR/test_data/ssh_keys/test_key`

### 3. Docker 卷挂载路径修正
- 使用 `$SCRIPT_DIR` 构建绝对路径进行卷挂载
- 确保容器能正确访问主机文件

### 4. 端口配置更新
- 默认 HTTP 端口从 8888 更新为 8080
- 避免与常见服务的端口冲突

## 文件结构

```
test/v0.0.3/linux/
├── build_test.sh          # 构建测试脚本
├── run_test.sh            # 运行测试脚本
├── functional_test.sh     # 功能测试脚本
├── log_rotation_test.sh   # 日志轮转测试脚本 (v0.0.3新功能)
├── test_log_size_reset.sh # 🆕 日志大小重置专项测试脚本 (容器重启修复验证)
├── cleanup_test.sh        # 清理测试脚本
├── start.sh              # 一键测试套件
├── test_paths.sh         # 路径验证脚本 (新增)
├── README.md             # 使用说明文档 (新增)
├── logs/                 # 测试日志目录 (自动创建)
└── test_data/           # 测试数据目录 (自动创建)
    ├── hexo_site/       # 测试站点文件
    └── ssh_keys/        # SSH 密钥文件
```

## 使用方式

### 方式1: 从测试目录运行 (推荐)
```bash
cd "/path/to/dockerfiledir/test/v0.0.3/linux"
./start.sh
```

### 方式2: 从任意目录运行
```bash
/path/to/dockerfiledir/test/v0.0.3/linux/start.sh
```

### 方式3: 单独运行各个测试
```bash
cd "/path/to/dockerfiledir/test/v0.0.3/linux"
./build_test.sh                # 构建镜像
./run_test.sh                  # 启动容器
./functional_test.sh           # 功能测试
./log_rotation_test.sh         # 日志轮转测试
./test_log_size_reset.sh       # 🆕 日志大小重置测试 (容器重启修复验证)
./cleanup_test.sh              # 清理环境
```

## 测试参数

### start.sh 参数
- `--clean-start`: 清理后重新开始测试
- `--help`: 显示帮助信息

### 各脚本参数

#### build_test.sh
```bash
./build_test.sh [TAG] [PLATFORM]
# TAG: 镜像标签 (默认: hexo-test:v0.0.3)
# PLATFORM: 平台架构 (默认: linux/amd64)
```

#### run_test.sh
```bash
./run_test.sh [TAG] [CONTAINER_NAME] [HTTP_PORT] [SSH_PORT] [PUID] [PGID] [TIMEZONE]
# TAG: 镜像标签 (默认: hexo-test:v0.0.3)
# CONTAINER_NAME: 容器名称 (默认: hexo-test-v003)
# HTTP_PORT: HTTP端口 (默认: 8080)
# SSH_PORT: SSH端口 (默认: 2222)
# PUID: 用户ID (默认: 1000)
# PGID: 组ID (默认: 1000)
# TIMEZONE: 时区 (默认: Asia/Shanghai)
```

#### functional_test.sh
```bash
./functional_test.sh [CONTAINER_NAME] [HTTP_PORT] [SSH_PORT]
# CONTAINER_NAME: 容器名称 (默认: hexo-test-v003)
# HTTP_PORT: HTTP端口 (默认: 8080)
# SSH_PORT: SSH端口 (默认: 2222)
```

#### log_rotation_test.sh
```bash
./log_rotation_test.sh [CONTAINER_NAME] [HTTP_PORT] [SSH_PORT] [OPTIONS]
# CONTAINER_NAME: 容器名称 (默认: hexo-test-v003)
# HTTP_PORT: HTTP端口 (默认: 8080)
# SSH_PORT: SSH端口 (默认: 2222)
# OPTIONS: --fast-test, --quick-gen, --log-threshold-mb N
```

#### test_log_size_reset.sh (🆕 容器重启修复验证)
```bash
./test_log_size_reset.sh [OPTIONS]
# --container-name NAME    容器名称 (默认: hexo-test-v003)
# --ssh-port PORT          SSH端口 (默认: 2222)
# --target-size-kb SIZE    目标日志大小KB (默认: 25)
# --verbose                详细输出模式
# --help                   显示帮助信息
```

此脚本专门验证容器重启时的日志监控修复功能，确保：
- 容器重启后不会重复输出旧的Git部署信息
- 日志位置跟踪文件正确工作
- 部署日志监控在重启后正常恢复

#### cleanup_test.sh
```bash
./cleanup_test.sh [CONTAINER_NAME] [IMAGE_TAG] [OPTIONS]
# CONTAINER_NAME: 容器名称 (默认: hexo-test-v003)
# IMAGE_TAG: 镜像标签 (默认: hexo-test:v0.0.3)
# OPTIONS: --remove-image, --remove-test-data, --remove-logs
```

### 使用示例
```bash
# 完整测试 (清理模式)
./start.sh --clean-start

# 自定义端口运行
./run_test.sh "hexo-test:v0.0.3" "my-hexo-test" 9999 3333

# 🆕 容器重启修复验证测试
./test_log_size_reset.sh

# 详细模式运行重启修复测试
./test_log_size_reset.sh --verbose

# 自定义目标大小测试
./test_log_size_reset.sh --target-size-kb 30

# 日志轮转快速测试
./log_rotation_test.sh --fast-test

# 彻底清理环境
./cleanup_test.sh --remove-image --remove-test-data --remove-logs
```

## 验证路径配置

运行路径验证脚本检查配置：
```bash
./test_paths.sh
```

此脚本会检查所有关键路径是否正确，并自动创建必需的目录。

## 系统要求

### 基本要求
- **操作系统**: Linux (Ubuntu 18.04+, Debian 10+, CentOS 7+)
- **Docker**: Docker Engine 20.10+
- **Shell**: Bash 4.0+
- **内存**: 至少 2GB 可用内存
- **磁盘**: 至少 5GB 可用磁盘空间

### 必需的系统工具
- `docker` - Docker 容器引擎
- `curl` - HTTP 客户端工具
- `ssh` - SSH 客户端
- `ssh-keygen` - SSH 密钥生成工具
- `netstat` - 网络状态查看工具

### 安装依赖 (Ubuntu/Debian)
```bash
# 更新包管理器
sudo apt-get update

# 安装 Docker
sudo apt-get install docker.io

# 安装其他工具
sudo apt-get install curl openssh-client net-tools

# 将用户添加到 docker 组
sudo usermod -aG docker $USER
newgrp docker
```

### 安装依赖 (CentOS/RHEL)
```bash
# 安装 Docker
sudo yum install docker

# 安装其他工具
sudo yum install curl openssh-clients net-tools

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# 将用户添加到 docker 组
sudo usermod -aG docker $USER
```

## 注意事项

1. **权限要求**: 确保有 Docker 使用权限（用户在 docker 组中）
2. **端口冲突**: 确保指定的端口未被占用
3. **SSH 密钥**: 测试脚本会自动生成 SSH 密钥对
4. **Docker 环境**: 确保 Docker 服务正在运行
5. **脚本权限**: 确保所有 .sh 文件有执行权限

## 故障排除

### 权限错误
```bash
# 设置脚本执行权限
chmod +x *.sh

# 检查 Docker 权限
docker version
```

### 路径不存在错误
```bash
# 运行路径验证
./test_paths.sh
```

### Docker 连接错误
```bash
# 检查 Docker 状态
sudo systemctl status docker

# 启动 Docker 服务
sudo systemctl start docker
```

### 端口占用错误
```bash
# 查看端口占用
netstat -tlnp | grep :8080
netstat -tlnp | grep :2222

# 杀死占用进程
sudo kill -9 <PID>
```

### 日志查看
```bash
# 查看最新测试日志
ls -la logs/ | tail -5

# 查看特定日志
tail -f logs/test_suite_*.log

# 搜索错误信息
grep -i error logs/*.log
```

## 高级用法

### 自定义配置
```bash
# 使用自定义镜像标签
export HEXO_IMAGE_TAG="my-hexo:custom"
./start.sh

# 使用自定义容器名称
export HEXO_CONTAINER_NAME="my-hexo-container"
./start.sh
```

### 批量测试
```bash
# 测试多个端口配置
for port in 8080 8081 8082; do
    ./run_test.sh "hexo-test:v0.0.3" "hexo-test-$port" $port $((port+1000))
    ./functional_test.sh "hexo-test-$port" $port $((port+1000))
    ./cleanup_test.sh "hexo-test-$port"
done
```

### 调试模式
```bash
# 启用详细输出
set -x
./start.sh
set +x
```

## 版本历史

### v0.0.3-linux-update (2025年5月30日)
- ✅ 修正了所有测试脚本的路径处理
- ✅ 统一了工作目录管理
- ✅ 更新了默认端口配置 (8888 → 8080)
- ✅ 添加了路径验证工具 `test_paths.sh`
- ✅ 改进了错误处理和日志记录
- ✅ 增强了脚本的可移植性和稳定性
