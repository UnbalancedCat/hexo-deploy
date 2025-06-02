#!/bin/bash
# Hexo Container v0.0.3 路径验证脚本 (Linux)
# test_paths.sh - 验证测试环境的路径配置

# 确保脚本在正确的目录下执行
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Hexo Container v0.0.3 路径验证工具 (Linux) ===${NC}"
echo -e "${BLUE}工作目录: $SCRIPT_DIR${NC}"
echo ""

# 验证结果数组
declare -a RESULTS=()

# 验证函数
check_path() {
    local description="$1"
    local path="$2"
    local should_exist="$3"  # true/false
    local create_if_missing="$4"  # true/false
    
    echo -n "检查 $description... "
    
    if [ "$should_exist" = "true" ]; then
        if [ -e "$path" ]; then
            echo -e "${GREEN}✓ 存在${NC}"
            RESULTS+=("PASS: $description")
            return 0
        else
            if [ "$create_if_missing" = "true" ]; then
                mkdir -p "$path" 2>/dev/null
                if [ -d "$path" ]; then
                    echo -e "${YELLOW}✓ 已创建${NC}"
                    RESULTS+=("CREATED: $description")
                    return 0
                else
                    echo -e "${RED}✗ 创建失败${NC}"
                    RESULTS+=("FAIL: $description - 创建失败")
                    return 1
                fi
            else
                echo -e "${RED}✗ 不存在${NC}"
                RESULTS+=("FAIL: $description - 路径不存在: $path")
                return 1
            fi
        fi
    else
        if [ -e "$path" ]; then
            echo -e "${YELLOW}! 存在 (不应该存在)${NC}"
            RESULTS+=("WARN: $description - 意外存在")
            return 0
        else
            echo -e "${GREEN}✓ 不存在 (正确)${NC}"
            RESULTS+=("PASS: $description")
            return 0
        fi
    fi
}

echo -e "${YELLOW}=== 关键路径验证 ===${NC}"

# 1. 验证 Dockerfile
check_path "Dockerfile_v0.0.3" "../../../Dockerfile_v0.0.3" true false

# 2. 验证和创建测试目录结构
echo ""
echo -e "${YELLOW}=== 测试目录结构验证 ===${NC}"

check_path "日志目录" "./logs" false true
check_path "测试数据目录" "./test_data" false true
check_path "Hexo 站点目录" "./test_data/hexo_site" false true
check_path "SSH 密钥目录" "./test_data/ssh_keys" false true

# 3. 验证测试脚本
echo ""
echo -e "${YELLOW}=== 测试脚本验证 ===${NC}"

SCRIPTS=(
    "start.sh"
    "build_test.sh"
    "run_test.sh"
    "functional_test.sh"
    "log_rotation_test.sh"
    "cleanup_test.sh"
)

for script in "${SCRIPTS[@]}"; do
    check_path "测试脚本: $script" "./$script" true false
    if [ -f "./$script" ]; then
        if [ -x "./$script" ]; then
            echo -e "  ${GREEN}✓ 可执行权限${NC}"
        else
            echo -e "  ${YELLOW}! 设置可执行权限${NC}"
            chmod +x "./$script"
        fi
    fi
done

# 4. 验证系统依赖
echo ""
echo -e "${YELLOW}=== 系统依赖验证 ===${NC}"

COMMANDS=(
    "docker:Docker"
    "curl:HTTP 客户端"
    "ssh:SSH 客户端"
    "ssh-keygen:SSH 密钥生成"
)

for cmd_info in "${COMMANDS[@]}"; do
    cmd=$(echo "$cmd_info" | cut -d':' -f1)
    desc=$(echo "$cmd_info" | cut -d':' -f2)
    
    echo -n "检查 $desc ($cmd)... "
    if command -v "$cmd" > /dev/null 2>&1; then
        version=$(${cmd} --version 2>&1 | head -n1 || echo "版本未知")
        echo -e "${GREEN}✓ 可用${NC} ($version)"
        RESULTS+=("PASS: $desc")
    else
        echo -e "${RED}✗ 未找到${NC}"
        RESULTS+=("FAIL: $desc - 命令未找到")
    fi
done

# 5. 验证网络端口
echo ""
echo -e "${YELLOW}=== 网络端口验证 ===${NC}"

DEFAULT_PORTS=(8080 2222)

for port in "${DEFAULT_PORTS[@]}"; do
    echo -n "检查端口 $port... "
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo -e "${YELLOW}! 已被占用${NC}"
        RESULTS+=("WARN: 端口 $port 已被占用")
    else
        echo -e "${GREEN}✓ 可用${NC}"
        RESULTS+=("PASS: 端口 $port")
    fi
done

# 6. 创建基本测试文件
echo ""
echo -e "${YELLOW}=== 创建基本测试文件 ===${NC}"

# 创建测试网站首页
TEST_INDEX="./test_data/hexo_site/index.html"
if [ ! -f "$TEST_INDEX" ]; then
    echo -n "创建测试网站首页... "
    cat > "$TEST_INDEX" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Hexo v0.0.3 Test Site - Linux</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007acc; padding-bottom: 10px; }
        .info { background: #e7f3ff; padding: 15px; border-radius: 4px; margin: 15px 0; }
        .status { display: inline-block; padding: 4px 8px; border-radius: 3px; color: white; background: #28a745; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hexo Container v0.0.3 测试站点 (Linux)</h1>
        <div class="info">
            <p><span class="status">运行中</span> 测试环境已就绪</p>
            <p><strong>平台:</strong> Linux</p>
            <p><strong>版本:</strong> v0.0.3</p>
        </div>
    </div>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            console.log('Hexo v0.0.3 测试页面加载完成');
        });
    </script>
</body>
</html>
EOF
    echo -e "${GREEN}✓ 完成${NC}"
    RESULTS+=("CREATED: 测试网站首页")
else
    echo -e "测试网站首页... ${GREEN}✓ 已存在${NC}"
    RESULTS+=("PASS: 测试网站首页")
fi

# 生成 SSH 密钥对
SSH_KEY_PATH="./test_data/ssh_keys/test_key"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -n "生成 SSH 密钥对... "
    if ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -q 2>/dev/null; then
        echo -e "${GREEN}✓ 完成${NC}"
        RESULTS+=("CREATED: SSH 密钥对")
    else
        echo -e "${RED}✗ 失败${NC}"
        RESULTS+=("FAIL: SSH 密钥对生成失败")
    fi
else
    echo -e "SSH 密钥对... ${GREEN}✓ 已存在${NC}"
    RESULTS+=("PASS: SSH 密钥对")
fi

# 显示结果汇总
echo ""
echo -e "${CYAN}=== 验证结果汇总 ===${NC}"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
CREATED_COUNT=0

for result in "${RESULTS[@]}"; do
    case "$result" in
        PASS:*)
            echo -e "${GREEN}✓${NC} ${result#PASS: }"
            ((PASS_COUNT++))
            ;;
        FAIL:*)
            echo -e "${RED}✗${NC} ${result#FAIL: }"
            ((FAIL_COUNT++))
            ;;
        WARN:*)
            echo -e "${YELLOW}!${NC} ${result#WARN: }"
            ((WARN_COUNT++))
            ;;
        CREATED:*)
            echo -e "${BLUE}+${NC} ${result#CREATED: }"
            ((CREATED_COUNT++))
            ;;
    esac
done

echo ""
echo -e "${CYAN}=== 统计信息 ===${NC}"
echo -e "通过: ${GREEN}$PASS_COUNT${NC}"
echo -e "创建: ${BLUE}$CREATED_COUNT${NC}"
echo -e "警告: ${YELLOW}$WARN_COUNT${NC}"
echo -e "失败: ${RED}$FAIL_COUNT${NC}"

# 提供建议
echo ""
echo -e "${CYAN}=== 建议 ===${NC}"

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}存在失败项，请检查并修复后再运行测试。${NC}"
    echo ""
    echo "常见解决方案："
    echo "1. 安装 Docker: sudo apt-get install docker.io"
    echo "2. 安装 curl: sudo apt-get install curl"
    echo "3. 安装 ssh: sudo apt-get install openssh-client"
    echo "4. 设置脚本权限: chmod +x *.sh"
    exit 1
elif [ $WARN_COUNT -gt 0 ]; then
    echo -e "${YELLOW}存在警告项，建议检查但不影响测试运行。${NC}"
    echo ""
    echo "如果端口被占用，可以在运行测试时指定其他端口。"
    exit 0
else
    echo -e "${GREEN}所有检查都通过了！测试环境已就绪。${NC}"
    echo ""
    echo "你现在可以运行："
    echo "  ./start.sh                    # 完整测试套件"
    echo "  ./build_test.sh              # 仅构建测试"
    echo "  ./run_test.sh                # 仅运行测试"
    echo "  ./functional_test.sh         # 仅功能测试"
    exit 0
fi
