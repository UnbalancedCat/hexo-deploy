#!/bin/bash
# Hexo Container v0.0.3 清理测试脚本 (Linux)
# cleanup_test.sh

# 确保脚本在正确的目录下执行
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 参数设置
CONTAINER_NAME=${1:-"hexo-test-v003"}
IMAGE_TAG=${2:-"hexo-test:v0.0.3"}
REMOVE_IMAGE=${3:-false}
REMOVE_TEST_DATA=${4:-false}
KEEP_LOGS=${5:-true}

echo "=== Hexo Container v0.0.3 清理测试 ==="
echo "工作目录: $SCRIPT_DIR"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-image)
            REMOVE_IMAGE=true
            shift
            ;;
        --remove-test-data)
            REMOVE_TEST_DATA=true
            shift
            ;;
        --remove-logs)
            KEEP_LOGS=false
            shift
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --remove-image       删除测试镜像"
            echo "  --remove-test-data   删除测试数据"
            echo "  --remove-logs        删除测试日志"
            echo "  -h, --help          显示此帮助信息"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

echo "=== Hexo Container v0.0.3 测试环境清理 ==="

CLEANUP_RESULTS=()

# 函数：记录清理结果
add_cleanup_result() {
    local action="$1"
    local status="$2"
    local message="$3"
    CLEANUP_RESULTS+=("$action:$status:$message:$(date)")
}

echo ""
echo "=== 步骤 1: 停止并删除容器 ==="

# 检查容器是否存在并运行
if docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo "发现容器: $CONTAINER_NAME"
    
    # 停止容器
    echo "停止容器..."
    if docker stop "$CONTAINER_NAME" 2>/dev/null; then
        echo "✅ 容器已停止"
        add_cleanup_result "停止容器" "SUCCESS" ""
    else
        echo "⚠️ 容器停止失败或容器已停止"
        add_cleanup_result "停止容器" "WARNING" "容器可能已停止"
    fi
    
    # 删除容器
    echo "删除容器..."
    if docker rm "$CONTAINER_NAME" 2>/dev/null; then
        echo "✅ 容器已删除"
        add_cleanup_result "删除容器" "SUCCESS" ""
    else
        echo "❌ 容器删除失败"
        add_cleanup_result "删除容器" "ERROR" "删除命令执行失败"
    fi
else
    echo "✅ 容器不存在，无需删除"
    add_cleanup_result "删除容器" "SKIPPED" "容器不存在"
fi

echo ""
echo "=== 步骤 2: 清理 Docker 镜像 ==="

if [ "$REMOVE_IMAGE" = true ]; then
    # 检查镜像是否存在
    if docker images --filter "reference=$IMAGE_TAG" --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_TAG"; then
        echo "删除测试镜像: $IMAGE_TAG"
        if docker rmi "$IMAGE_TAG" 2>/dev/null; then
            echo "✅ 测试镜像已删除"
            add_cleanup_result "删除测试镜像" "SUCCESS" ""
        else
            echo "❌ 测试镜像删除失败"
            add_cleanup_result "删除测试镜像" "ERROR" "镜像可能被其他容器使用"
        fi
    else
        echo "✅ 测试镜像不存在，无需删除"
        add_cleanup_result "删除测试镜像" "SKIPPED" "镜像不存在"
    fi
    
    # 清理悬挂镜像
    echo "清理悬挂镜像..."
    if docker image prune -f >/dev/null 2>&1; then
        echo "✅ 悬挂镜像已清理"
        add_cleanup_result "清理悬挂镜像" "SUCCESS" ""
    else
        echo "⚠️ 清理悬挂镜像失败"
        add_cleanup_result "清理悬挂镜像" "WARNING" "清理命令执行失败"
    fi
else
    echo "⏭️ 跳过镜像删除 (使用 --remove-image 参数强制删除)"
    add_cleanup_result "删除测试镜像" "SKIPPED" "用户选择保留"
fi

echo ""
echo "=== 步骤 3: 清理测试数据 ==="

if [ "$REMOVE_TEST_DATA" = true ]; then
    TEST_DATA_DIR="./test_data"
    if [ -d "$TEST_DATA_DIR" ]; then
        echo "删除测试数据目录: $TEST_DATA_DIR"
        if rm -rf "$TEST_DATA_DIR"; then
            echo "✅ 测试数据已删除"
            add_cleanup_result "删除测试数据" "SUCCESS" ""
        else
            echo "❌ 删除测试数据失败"
            add_cleanup_result "删除测试数据" "ERROR" "权限不足或目录被占用"
        fi
    else
        echo "✅ 测试数据目录不存在"
        add_cleanup_result "删除测试数据" "SKIPPED" "目录不存在"
    fi
else
    echo "⏭️ 保留测试数据 (使用 --remove-test-data 参数强制删除)"
    add_cleanup_result "删除测试数据" "SKIPPED" "用户选择保留"
fi

echo ""
echo "=== 步骤 4: 清理测试日志 ==="

if [ "$KEEP_LOGS" = false ]; then
    LOGS_DIR="./logs"
    if [ -d "$LOGS_DIR" ]; then
        echo "删除测试日志目录: $LOGS_DIR"
        if rm -rf "$LOGS_DIR"; then
            echo "✅ 测试日志已删除"
            add_cleanup_result "删除测试日志" "SUCCESS" ""
        else
            echo "❌ 删除测试日志失败"
            add_cleanup_result "删除测试日志" "ERROR" "权限不足或目录被占用"
        fi
    else
        echo "✅ 测试日志目录不存在"
        add_cleanup_result "删除测试日志" "SKIPPED" "目录不存在"
    fi
else
    echo "⏭️ 保留测试日志 (日志文件保存在 ./logs 目录)"
    add_cleanup_result "删除测试日志" "SKIPPED" "用户选择保留"
    
    # 显示保留的日志文件
    LOGS_DIR="./logs"
    if [ -d "$LOGS_DIR" ]; then
        LOG_FILES=$(find "$LOGS_DIR" -type f -name "*.log" -o -name "*.txt" | sort -t_ -k2 -r)
        if [ -n "$LOG_FILES" ]; then
            echo ""
            echo "保留的日志文件:"
            echo "$LOG_FILES" | while read -r file; do
                size=$(du -h "$file" | cut -f1)
                modified=$(stat -c %y "$file" 2>/dev/null || date -r "$file" 2>/dev/null || echo "未知时间")
                echo "  $(basename "$file") ($size) - $modified"
            done
        fi
    fi
fi

echo ""
echo "=== 步骤 5: 清理 Docker 系统资源 ==="

# 清理未使用的网络
echo "清理未使用的 Docker 网络..."
if docker network prune -f >/dev/null 2>&1; then
    echo "✅ 未使用的网络已清理"
    add_cleanup_result "清理网络" "SUCCESS" ""
else
    echo "⚠️ 网络清理失败"
    add_cleanup_result "清理网络" "WARNING" "清理命令执行失败"
fi

# 清理未使用的卷
echo "清理未使用的 Docker 卷..."
if docker volume prune -f >/dev/null 2>&1; then
    echo "✅ 未使用的卷已清理"
    add_cleanup_result "清理卷" "SUCCESS" ""
else
    echo "⚠️ 卷清理失败"
    add_cleanup_result "清理卷" "WARNING" "清理命令执行失败"
fi

echo ""
echo "=== 步骤 6: 验证清理结果 ==="

# 检查容器是否已完全删除
if ! docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo "✅ 容器清理验证通过"
else
    REMAINING=$(docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}")
    echo "❌ 仍有容器残留: $REMAINING"
fi

# 检查镜像清理情况
if [ "$REMOVE_IMAGE" = true ]; then
    if ! docker images --filter "reference=$IMAGE_TAG" --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_TAG"; then
        echo "✅ 镜像清理验证通过"
    else
        REMAINING=$(docker images --filter "reference=$IMAGE_TAG" --format "{{.Repository}}:{{.Tag}}")
        echo "❌ 仍有镜像残留: $REMAINING"
    fi
fi

# 显示当前 Docker 资源使用情况
echo ""
echo "=== Docker 资源使用情况 ==="

echo "容器数量:"
CONTAINER_COUNT=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" | wc -l)
if [ $CONTAINER_COUNT -gt 1 ]; then
    docker ps -a --format "table {{.Names}}\t{{.Status}}" | head -10
    echo "  总计: $((CONTAINER_COUNT - 1)) 个容器"
else
    echo "  无容器运行"
fi

echo ""
echo "镜像数量:"
IMAGE_COUNT=$(docker images --format "{{.Repository}}" | wc -l)
echo "  总计: $IMAGE_COUNT 个镜像"

echo ""
echo "磁盘使用:"
if command -v docker >/dev/null 2>&1; then
    docker system df 2>/dev/null || echo "  无法获取磁盘使用信息"
fi

# 生成清理报告
echo ""
echo "=== 清理报告 ==="

SUCCESS_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0
SKIPPED_COUNT=0
TOTAL_ACTIONS=0

for result in "${CLEANUP_RESULTS[@]}"; do
    TOTAL_ACTIONS=$((TOTAL_ACTIONS + 1))
    status=$(echo "$result" | cut -d: -f2)
    case $status in
        SUCCESS) SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) ;;
        WARNING) WARNING_COUNT=$((WARNING_COUNT + 1)) ;;
        ERROR) ERROR_COUNT=$((ERROR_COUNT + 1)) ;;
        SKIPPED) SKIPPED_COUNT=$((SKIPPED_COUNT + 1)) ;;
    esac
done

echo "清理操作统计:"
echo "  成功: $SUCCESS_COUNT"
echo "  警告: $WARNING_COUNT"
echo "  错误: $ERROR_COUNT"
echo "  跳过: $SKIPPED_COUNT"
echo "  总计: $TOTAL_ACTIONS"

# 详细清理结果
echo ""
echo "详细清理结果:"
for result in "${CLEANUP_RESULTS[@]}"; do
    IFS=':' read -r action status message timestamp <<< "$result"
    case $status in
        SUCCESS) color="✅" ;;
        WARNING) color="⚠️" ;;
        ERROR) color="❌" ;;
        SKIPPED) color="⏭️" ;;
        *) color="ℹ️" ;;
    esac
    
    if [ -n "$message" ]; then
        echo "  $color $action: $status - $message"
    else
        echo "  $color $action: $status"
    fi
done

# 保存清理报告
if [ "$KEEP_LOGS" = true ] && [ -d "./logs" ]; then
    REPORT_CONTENT="=== Hexo Container v0.0.3 测试环境清理报告 ===
清理时间: $(date)
容器名称: $CONTAINER_NAME
镜像标签: $IMAGE_TAG

=== 清理参数 ===
删除镜像: $REMOVE_IMAGE
删除测试数据: $REMOVE_TEST_DATA
保留日志: $KEEP_LOGS

=== 清理统计 ===
成功: $SUCCESS_COUNT
警告: $WARNING_COUNT
错误: $ERROR_COUNT
跳过: $SKIPPED_COUNT
总计: $TOTAL_ACTIONS

=== 详细结果 ==="

    for result in "${CLEANUP_RESULTS[@]}"; do
        IFS=':' read -r action status message timestamp <<< "$result"
        REPORT_CONTENT="$REPORT_CONTENT
$timestamp - $action: $status $message"
    done

    REPORT_FILE="./logs/cleanup_report_$(date +%Y%m%d_%H%M%S).txt"
    echo "$REPORT_CONTENT" > "$REPORT_FILE"
    echo ""
    echo "清理报告已保存: $REPORT_FILE"
fi

# 使用建议
echo ""
echo "=== 使用建议 ==="
echo "重新开始测试请运行:"
echo "  ./build_test.sh       # 重新构建镜像"
echo "  ./run_test.sh         # 重新运行容器"
echo "  ./functional_test.sh  # 执行功能测试"

echo ""
echo "完全清理 (包括镜像和数据) 请运行:"
echo "  ./cleanup_test.sh --remove-image --remove-test-data"

echo ""
echo "=== 清理完成 ==="

# 根据清理结果设置退出代码
if [ $ERROR_COUNT -eq 0 ]; then
    echo "🎉 清理操作成功完成！"
    exit 0
else
    echo "⚠️ 清理过程中出现错误，请检查详细报告。"
    exit 1
fi
