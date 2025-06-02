#!/bin/bash
# Hexo Container v0.0.3 运行测试脚本 (Linux)
# run_test.sh

# 确保脚本在正确的目录下执行
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 参数设置
TAG=${1:-"hexo-test:v0.0.3"}
CONTAINER_NAME=${2:-"hexo-test-v003"}
HTTP_PORT=${3:-8080}
SSH_PORT=${4:-2222}
PUID=${5:-1000}
PGID=${6:-1000}
TIMEZONE=${7:-"Asia/Shanghai"}

echo "=== Hexo Container v0.0.3 运行测试 ==="
echo "工作目录: $SCRIPT_DIR"

# 创建日志目录 (在测试脚本目录下)
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

# 创建测试数据目录 (在测试脚本目录下)
TEST_DATA_DIR="./test_data"
HEXO_SITE_DIR="$TEST_DATA_DIR/hexo_site"
SSH_KEYS_DIR="$TEST_DATA_DIR/ssh_keys"

echo "创建测试数据目录..."
mkdir -p "$HEXO_SITE_DIR"
mkdir -p "$SSH_KEYS_DIR"

# 创建测试用的 HTML 文件
echo "创建测试网站文件..."
cat > "$HEXO_SITE_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Hexo v0.0.3 Test Site</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007acc; padding-bottom: 10px; }
        .info { background: #e7f3ff; padding: 15px; border-radius: 4px; margin: 15px 0; }
        .status { display: inline-block; padding: 4px 8px; border-radius: 3px; color: white; background: #28a745; }
        ul { list-style-type: none; padding: 0; }
        li { padding: 8px; margin: 5px 0; background: #f8f9fa; border-left: 4px solid #007acc; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hexo Container v0.0.3 测试站点</h1>
        <div class="info">
            <p><strong>测试时间:</strong> <span id="time"></span></p>
            <p><strong>版本:</strong> <span class="status">v0.0.3</span></p>
            <p><strong>状态:</strong> <span class="status">运行中</span></p>
        </div>
        
        <h2>v0.0.3 新功能测试</h2>
        <ul>
            <li>定期日志轮转 (每30分钟检查)</li>
            <li>Git Hook 日志权限修复</li>
            <li>增强的部署日志管理</li>
            <li>智能日志文件大小控制</li>
            <li>自动旧日志清理</li>
            <li>时间戳备份文件生成</li>
        </ul>
        
        <h2>测试链接</h2>
        <ul>
            <li><a href="/health">健康检查端点</a></li>
            <li>SSH 连接: ssh -p 2222 hexo@localhost</li>
        </ul>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString('zh-CN');
    </script>
</body>
</html>
EOF

# 生成 SSH 密钥对 (如果不存在)
SSH_KEY_PATH="$SSH_KEYS_DIR/test_key"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "生成 SSH 密钥对..."
    if ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -q; then
        echo "[SUCCESS] SSH 密钥生成成功"
    else
        echo "[FAIL] SSH 密钥生成失败"
    fi
fi

# 停止并删除已存在的容器
echo "清理旧容器..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# 检查端口是否被占用
if netstat -tlnp 2>/dev/null | grep -q ":$HTTP_PORT "; then
    echo "[WARNING] 警告: 端口 $HTTP_PORT 已被占用"
fi
if netstat -tlnp 2>/dev/null | grep -q ":$SSH_PORT "; then
    echo "[WARNING] 警告: 端口 $SSH_PORT 已被占用"
fi

# 构建 Docker 运行命令
echo ""
echo "启动容器..."

DOCKER_CMD="docker run -d \
  --name $CONTAINER_NAME \
  -p $HTTP_PORT:80 \
  -p $SSH_PORT:22 \
  -e PUID=$PUID \
  -e PGID=$PGID \
  -e TZ=$TIMEZONE \
  -e HTTP_PORT=80 \
  -e SSH_PORT=22 \
    -v $SCRIPT_DIR/test_data/hexo_site:/home/www/hexo \
  -v $SCRIPT_DIR/test_data/ssh_keys:/home/hexo/.ssh \
  -v $SCRIPT_DIR/logs:/var/log/container \
  $TAG"

echo "执行命令:"
echo "$DOCKER_CMD"

# 执行 Docker 运行命令
if CONTAINER_ID=$($DOCKER_CMD); then
    echo ""
    echo "=== 容器启动成功 ==="
    echo "容器 ID: $CONTAINER_ID"
    echo "容器名称: $CONTAINER_NAME"
    
    # 等待容器启动
    echo ""
    echo "等待容器完全启动 (增加等待时间)..."
    sleep 30 # MODIFIED: Increased sleep time to 30 seconds
    
    # 检查容器状态
    echo ""
    echo "=== 容器状态 ==="
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # 显示访问信息
    echo ""
    echo "=== 访问信息 ==="
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo "HTTP 访问地址: http://$LOCAL_IP:$HTTP_PORT"
    echo "健康检查地址: http://$LOCAL_IP:$HTTP_PORT/health"
    echo "SSH 连接命令: ssh -p $SSH_PORT -i test_data/ssh_keys/test_key hexo@$LOCAL_IP"
    
    # 显示容器日志
    echo ""
    echo "=== 容器启动日志 (最后20行) ==="
    docker logs "$CONTAINER_NAME" --tail 20
    
    # 基础健康检查
    echo ""
    echo "=== 基础健康检查 ==="
    sleep 5
    
    # 健康检查
    if curl -f "http://localhost:$HTTP_PORT/health" --max-time 10 >/dev/null 2>&1; then
        echo "[SUCCESS] 健康检查通过"
    else
        echo "[FAIL] 健康检查失败"
    fi
    
    # HTTP 服务检查
    if curl -f "http://localhost:$HTTP_PORT" --max-time 10 >/dev/null 2>&1; then
        echo "[SUCCESS] HTTP 服务正常"
    else
        echo "[FAIL] HTTP 服务异常"
    fi
    
    echo ""
    echo "=== 运行测试完成 ==="
    echo "容器已成功启动并运行。使用以下命令进行进一步测试:"
    echo "  ./functional_test.sh    # 功能测试"
    echo "  ./log_rotation_test.sh  # 日志轮转测试"
    echo "  ./cleanup_test.sh       # 清理测试环境"
    
    exit 0
else
    echo ""
    echo "=== 容器启动失败 ==="
    echo "[ERROR] Docker 容器启动失败"
    
    # 尝试显示错误日志
    if docker logs "$CONTAINER_NAME" 2>/dev/null; then
        echo ""
        echo "=== 容器错误日志 ==="
        docker logs "$CONTAINER_NAME"
    fi
    
    exit 1
fi
