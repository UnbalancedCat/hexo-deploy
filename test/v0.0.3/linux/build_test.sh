#!/bin/bash
# Hexo Container v0.0.3 构建测试脚本 (Linux)
# build_test.sh

# 确保脚本在正确的目录下执行
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 参数设置
TAG=${1:-"hexo-test:v0.0.3"}
PLATFORM=${2:-"linux/amd64"}

echo "=== Hexo Container v0.0.3 构建测试 ==="
echo "镜像标签: $TAG"
echo "平台架构: $PLATFORM"
echo "工作目录: $SCRIPT_DIR"

# Dockerfile 路径 (相对于测试脚本目录)
DOCKERFILE_PATH="../../../Dockerfile_v0.0.3"

# 检查 Dockerfile 是否存在
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "❌ 错误: Dockerfile 不存在: $DOCKERFILE_PATH"
    echo "完整路径: $(realpath "$DOCKERFILE_PATH" 2>/dev/null || echo "路径无法解析")"
    exit 1
fi

# 创建日志目录 (在测试脚本目录下)
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

# 记录开始时间
START_TIME=$(LC_ALL=C date)
LOG_FILE="$LOG_DIR/build_$(date +%Y%m%d_%H%M%S).log"

echo "构建开始时间: $START_TIME"
echo "日志文件: $LOG_FILE"

# 执行构建
echo ""
echo "开始构建镜像..."

# 获取 Dockerfile 所在目录的绝对路径
DOCKERFILE_DIR="$(cd "$(dirname "$DOCKERFILE_PATH")" && pwd)"
DOCKERFILE_NAME=$(basename "$DOCKERFILE_PATH")

echo "Dockerfile 目录: $DOCKERFILE_DIR"
echo "Dockerfile 文件: $DOCKERFILE_NAME"

# 切换到 Dockerfile 所在目录进行构建
cd "$DOCKERFILE_DIR" || exit 1

BUILD_CMD="docker build -f $DOCKERFILE_NAME -t $TAG --platform $PLATFORM ."
echo "执行命令: $BUILD_CMD"

# 执行构建并记录日志
if $BUILD_CMD 2>&1 | tee "$SCRIPT_DIR/$LOG_FILE"; then
    END_TIME=$(LC_ALL=C date)
    
    # 计算构建时间
    START_TIMESTAMP=$(date -d "$START_TIME" +%s)
    END_TIMESTAMP=$(date -d "$END_TIME" +%s)
    DURATION=$((END_TIMESTAMP - START_TIMESTAMP))
    DURATION_MIN=$(echo "scale=2; $DURATION / 60" | bc 2>/dev/null || echo "$(($DURATION / 60))")
    
    echo ""
    echo "=== 构建成功 ==="
    echo "构建结束时间: $END_TIME"
    echo "构建耗时: ${DURATION_MIN} 分钟"
    
    # 显示镜像信息
    echo ""
    echo "=== 镜像信息 ==="
    docker images "$TAG"
    
    # 显示镜像详细信息
    echo ""
    echo "=== 镜像详细信息 ==="
    if command -v jq > /dev/null 2>&1; then
        IMAGE_SIZE=$(docker inspect "$TAG" | jq -r '.[0].Size')
        IMAGE_SIZE_MB=$(echo "scale=2; $IMAGE_SIZE / 1024 / 1024" | bc 2>/dev/null || echo "$(($IMAGE_SIZE / 1024 / 1024))")
        IMAGE_CREATED=$(docker inspect "$TAG" | jq -r '.[0].Created')
        IMAGE_ARCH=$(docker inspect "$TAG" | jq -r '.[0].Architecture')
        
        echo "镜像大小: ${IMAGE_SIZE_MB} MB"
        echo "创建时间: $IMAGE_CREATED"
        echo "架构: $IMAGE_ARCH"
    else
        echo "镜像大小: $(docker inspect "$TAG" --format='{{.Size}}' | awk '{print int($1/1024/1024) " MB"}')"
        echo "创建时间: $(docker inspect "$TAG" --format='{{.Created}}')"
        echo "架构: $(docker inspect "$TAG" --format='{{.Architecture}}')"
    fi
    
    # 输出构建统计
    echo ""
    echo "=== 构建统计 ==="
    LAYER_COUNT=$(grep -c "^Step [0-9]*/" "$SCRIPT_DIR/$LOG_FILE" 2>/dev/null || echo "未知")
    echo "构建步骤数: $LAYER_COUNT"
    
    cd "$SCRIPT_DIR"
    exit 0
else
    echo ""
    echo "=== 构建失败 ==="
    echo "详细日志请查看: $LOG_FILE"
    
    # 显示最后几行日志
    echo ""
    echo "=== 最后10行构建日志 ==="
    tail -10 "$SCRIPT_DIR/$LOG_FILE"
    
    cd "$SCRIPT_DIR"
    exit 1
fi

echo ""
echo "构建测试完成。"
echo "详细日志保存在: $LOG_FILE"
