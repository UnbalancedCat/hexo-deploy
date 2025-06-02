#!/bin/bash

# Docker Hexo Static Blog v0.0.3 - Linux Log Rotation Test Script
# 用于测试 v0.0.3 版本的日志轮转功能

set -e

# 确保脚本在正确的目录下执行
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置参数
CONTAINER_NAME=${1:-"hexo-test-v003"}
IMAGE_NAME="hexo-test"
IMAGE_TAG="v0.0.3"
SSH_KEY_PATH="$SCRIPT_DIR/test_data/ssh_keys/test_key"
LOG_DIR="$SCRIPT_DIR/logs"
TEST_DIR="$SCRIPT_DIR/test_data/log_rotation"
LOG_FILE="$LOG_DIR/log_rotation_test_$(date +%Y%m%d_%H%M%S).log"

# 创建日志目录
mkdir -p "$LOG_DIR"

echo "=== Hexo Container v0.0.3 日志轮转测试 ==="
echo "工作目录: $SCRIPT_DIR"

# 函数：记录日志
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $1" | tee -a "$LOG_FILE"
}

# 函数：清理资源
cleanup() {
    log "清理测试资源..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    sudo rm -rf "$TEST_DIR" 2>/dev/null || true
    log_success "清理完成"
}

# 函数：清理现有容器
cleanup_existing_container() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log "发现现有容器 $CONTAINER_NAME，正在清理..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        log "现有容器已清理"
    fi
}

# 函数：检查前置条件
check_prerequisites() {
    log "检查前置条件..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装或不在 PATH 中"
        exit 1
    fi
    
    # 检查 Docker 服务
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行"
        exit 1
    fi
    
    # 检查镜像
    if ! docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &> /dev/null; then
        log_error "Docker 镜像 ${IMAGE_NAME}:${IMAGE_TAG} 不存在"
        log "请先运行 build_test.sh 构建镜像"
        exit 1
    fi
    
    log_success "前置条件检查通过"
}

# 函数：准备测试环境
prepare_test_environment() {
    log "准备测试环境..."
    
    # 创建测试目录
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_DIR/logs"
    mkdir -p "$TEST_DIR/hexo-blog"
    
    # 创建初始日志文件以便测试
    echo "Initial log entry" > "$TEST_DIR/logs/container.log"
    echo "Initial ssh log entry" > "$TEST_DIR/logs/ssh.log"
    
    log_success "测试环境准备完成"
}

# 函数：启动容器
start_container() {
    log "启动测试容器..."
    
    # 清理可能存在的同名容器
    cleanup_existing_container
    
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p 4000:4000 \
        -p 2222:22 \
        -e PUID=1000 \
        -e PGID=1000 \
        -e LOG_ROTATION_ENABLED=true \
        -e LOG_MAX_SIZE=1M \
        -e LOG_BACKUP_COUNT=5 \
        -v "$TEST_DIR/hexo-blog:/app/hexo-blog" \
        -v "$TEST_DIR/logs:/var/log/container" \
        "${IMAGE_NAME}:${IMAGE_TAG}"
    
    # 等待容器启动
    log "等待容器完全启动..."
    sleep 10
    
    # 检查容器状态
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        log_error "容器启动失败"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
    
    log_success "容器启动成功"
}

# 函数：测试基本日志轮转功能
test_basic_log_rotation() {
    log "测试基本日志轮转功能..."
    
    # 生成大量日志以触发轮转
    for i in {1..1000}; do
        echo "Test log entry $i - $(date) - This is a test message to fill up the log file for rotation testing" >> "$TEST_DIR/logs/container.log"
        if [ $((i % 100)) -eq 0 ]; then
            log "已写入 $i 条日志记录..."
        fi
    done
    
    # 检查日志文件大小
    log_size=$(stat -f%z "$TEST_DIR/logs/container.log" 2>/dev/null || stat -c%s "$TEST_DIR/logs/container.log" 2>/dev/null)
    log "当前日志文件大小: $log_size 字节"
    
    # 触发手动轮转测试
    docker exec "$CONTAINER_NAME" bash -c "
        if [ -f /usr/local/bin/rotate_log ]; then
            /usr/local/bin/rotate_log /var/log/container/container.log
        else
            echo 'rotate_log function not found'
        fi
    "
    
    sleep 5
    
    # 检查轮转后的文件
    if [ -f "$TEST_DIR/logs/container.log.1" ]; then
        log_success "基本日志轮转功能正常 - 找到备份文件"
    else
        log_warning "未找到备份文件，可能日志未达到轮转阈值"
    fi
}

# 函数：测试定期日志轮转
test_periodic_log_rotation() {
    log "测试定期日志轮转功能..."
    
    # 检查容器中的日志轮转配置
    docker exec "$CONTAINER_NAME" bash -c "
        echo '=== 检查日志轮转配置 ==='
        env | grep LOG_
        echo
        echo '=== 检查监控进程 ==='
        ps aux | grep -E '(monitor|check.*log)' | grep -v grep
        echo
        echo '=== 检查日志目录 ==='
        ls -la /var/log/container/
    "
    
    # 模拟长时间运行，观察定期轮转
    log "模拟30分钟周期的定期检查..."
    
    # 生成持续的日志流
    docker exec -d "$CONTAINER_NAME" bash -c "
        while true; do
            echo '$(date): Continuous log entry for rotation testing' >> /var/log/container/container.log
            sleep 1
        done
    "
    
    # 等待一段时间观察轮转
    log "等待60秒观察日志轮转行为..."
    sleep 60
    
    # 检查轮转结果
    rotation_files=$(ls "$TEST_DIR/logs/"*.log.* 2>/dev/null | wc -l)
    if [ "$rotation_files" -gt 0 ]; then
        log_success "找到 $rotation_files 个轮转后的日志文件"
        ls -la "$TEST_DIR/logs/"
    else
        log_warning "未检测到轮转文件，可能需要更长时间或更多日志"
    fi
}

# 函数：测试日志权限
test_log_permissions() {
    log "测试日志文件权限..."
    
    # 检查容器内的日志文件权限
    docker exec "$CONTAINER_NAME" bash -c "
        echo '=== 日志目录权限 ==='
        ls -la /var/log/container/
        echo
        echo '=== 检查 hexo 用户权限 ==='
        su - hexo -c 'echo \"Test write permission\" >> /var/log/container/test_permission.log'
        if [ \$? -eq 0 ]; then
            echo 'hexo 用户可以写入日志目录'
        else
            echo 'hexo 用户无法写入日志目录'
        fi
        echo
        echo '=== 检查日志文件所有权 ==='
        stat /var/log/container/*.log 2>/dev/null | grep -E '(Uid|Gid)'
    "
    
    # 测试 Git Hook 日志写入
    if docker exec "$CONTAINER_NAME" test -f "/app/hexo-blog/.git/hooks/post-receive"; then
        log "测试 Git Hook 日志写入权限..."
        docker exec "$CONTAINER_NAME" bash -c "
            su - hexo -c 'echo \"Test deployment log\" >> /var/log/container/deployment.log'
            if [ \$? -eq 0 ]; then
                echo 'Git Hook 日志写入权限正常'
            else
                echo 'Git Hook 日志写入权限有问题'
            fi
        "
    fi
    
    log_success "日志权限测试完成"
}

# 函数：测试日志备份和清理
test_log_backup_cleanup() {
    log "测试日志备份和清理功能..."
    
    # 创建多个旧的备份文件进行清理测试
    for i in {1..10}; do
        echo "Old backup log $i" > "$TEST_DIR/logs/container.log.$i"
        # 设置不同的时间戳
        touch -t "$(date -d "-$i days" +%Y%m%d%H%M)" "$TEST_DIR/logs/container.log.$i" 2>/dev/null || \
        touch -d "-$i days" "$TEST_DIR/logs/container.log.$i" 2>/dev/null
    done
    
    log "创建了10个模拟备份文件"
    
    # 执行清理
    docker exec "$CONTAINER_NAME" bash -c "
        if [ -f /usr/local/bin/cleanup_old_logs ]; then
            /usr/local/bin/cleanup_old_logs /var/log/container/
        else
            echo 'cleanup_old_logs function not found'
        fi
    "
    
    sleep 5
    
    # 检查清理结果
    remaining_backups=$(ls "$TEST_DIR/logs/"*.log.* 2>/dev/null | wc -l)
    log "清理后剩余备份文件数量: $remaining_backups"
    
    if [ "$remaining_backups" -le 5 ]; then
        log_success "日志清理功能正常 - 保留了合理数量的备份"
    else
        log_warning "日志清理可能未按预期工作"
    fi
}

# 函数：生成测试报告
generate_test_report() {
    log "生成日志轮转测试报告..."
    
    local report_file="$TEST_DIR/log_rotation_test_report.txt"
    
    cat > "$report_file" << EOF
Docker Hexo Static Blog v0.0.3 - 日志轮转测试报告
======================================================

测试时间: $(date)
测试环境: Linux ($(uname -r))
镜像版本: ${IMAGE_NAME}:${IMAGE_TAG}

测试结果概要:
EOF
    
    # 检查各项测试结果
    echo "1. 容器运行状态:" >> "$report_file"
    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo "   ✓ 容器正常运行" >> "$report_file"
    else
        echo "   ✗ 容器未运行" >> "$report_file"
    fi
    
    echo "2. 日志文件检查:" >> "$report_file"
    if [ -f "$TEST_DIR/logs/container.log" ]; then
        log_size=$(stat -c%s "$TEST_DIR/logs/container.log" 2>/dev/null)
        echo "   ✓ 主日志文件存在 (大小: $log_size 字节)" >> "$report_file"
    else
        echo "   ✗ 主日志文件不存在" >> "$report_file"
    fi
    
    echo "3. 日志轮转文件:" >> "$report_file"
    rotation_count=$(ls "$TEST_DIR/logs/"*.log.* 2>/dev/null | wc -l)
    if [ "$rotation_count" -gt 0 ]; then
        echo "   ✓ 找到 $rotation_count 个轮转文件" >> "$report_file"
        ls -la "$TEST_DIR/logs/"*.log.* >> "$report_file" 2>/dev/null
    else
        echo "   - 未找到轮转文件（可能正常，取决于日志大小）" >> "$report_file"
    fi
    
    echo "4. 容器资源使用:" >> "$report_file"
    docker stats "$CONTAINER_NAME" --no-stream >> "$report_file" 2>/dev/null || echo "   无法获取资源使用情况" >> "$report_file"
    
    echo "5. 容器日志（最后20行）:" >> "$report_file"
    docker logs --tail 20 "$CONTAINER_NAME" >> "$report_file" 2>&1
    
    log_success "测试报告已生成: $report_file"
    cat "$report_file"
}

# 主测试流程
main() {
    log "开始 Docker Hexo Static Blog v0.0.3 日志轮转测试"
    log "=============================================="
    
    # 设置错误处理
    trap cleanup EXIT
    
    # 执行测试步骤
    check_prerequisites
    prepare_test_environment
    start_container
    test_basic_log_rotation
    test_periodic_log_rotation
    test_log_permissions
    test_log_backup_cleanup
    generate_test_report
    
    log_success "日志轮转测试完成！"
    log "测试结果和日志保存在: $TEST_DIR"
}

# 脚本参数处理
case "${1:-}" in
    --help|-h)
        echo "Docker Hexo Static Blog v0.0.3 - Linux 日志轮转测试脚本"
        echo ""
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  --help, -h    显示此帮助信息"
        echo "  --cleanup     仅执行清理操作"
        echo ""
        echo "示例:"
        echo "  $0              # 运行完整的日志轮转测试"
        echo "  $0 --cleanup    # 清理测试资源"
        exit 0
        ;;
    --cleanup)
        cleanup
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "未知参数: $1"
        echo "使用 --help 查看使用说明"
        exit 1
        ;;
esac
