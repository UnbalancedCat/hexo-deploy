#!/bin/bash
# Hexo Container v0.0.3 功能测试脚本 (Linux)
# functional_test.sh

# 确保脚本在正确的目录下执行
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 参数设置
CONTAINER_NAME=${1:-"hexo-test-v003"}
HTTP_PORT=${2:-8080}
SSH_PORT=${3:-2222}
SSH_KEY_PATH="$SCRIPT_DIR/test_data/ssh_keys/test_key"

echo "=== Hexo Container v0.0.3 功能测试 ==="
echo "工作目录: $SCRIPT_DIR"

# 创建日志文件 (在测试脚本目录下)
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

TEST_LOG="$LOG_DIR/functional_test_$(date +%Y%m%d_%H%M%S).log"
TEST_RESULTS=()

# 测试函数
run_test() {
    local test_name="$1"
    local description="$2"
    local test_command="$3"
    
    echo ""
    echo "=== $test_name ==="
    echo "$description"
    
    local start_time=$(date +%s)
    local status
    local message=""
    
    if eval "$test_command"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "✅ $test_name 通过 (${duration}s)"
        status="PASS"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "❌ $test_name 失败 (${duration}s)"
        status="FAIL"
    fi
    
    TEST_RESULTS+=("$test_name:$status:$duration")
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $test_name - $status (${duration}s)" >> "$TEST_LOG"
}

# 检查容器是否运行
echo "检查容器状态..."
if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo "❌ 容器 $CONTAINER_NAME 未运行，请先运行 run_test.sh"
    exit 1
fi
echo "✅ 容器正在运行"

# 测试 1: HTTP 服务基础测试
run_test "HTTP服务基础测试" "测试主页是否可以正常访问" \
    "curl -f http://localhost:$HTTP_PORT --max-time 10 >/dev/null 2>&1"

# 测试 2: 健康检查端点测试
run_test "健康检查端点测试" "测试 /health 端点是否返回正确响应" \
    "curl -f http://localhost:$HTTP_PORT/health --max-time 5 2>/dev/null | grep -q '^healthy$'"

# 测试 3: SSH 服务连接测试
run_test "SSH服务连接测试" "测试 SSH 服务是否可以正常连接" \
    'if [ -f "$SSH_KEY_PATH" ]; then
        docker exec "$CONTAINER_NAME" bash -c "mkdir -p /home/hexo/.ssh && cp /home/hexo/.ssh/test_key.pub /home/hexo/.ssh/authorized_keys && chown -R hexo:hexo /home/hexo/.ssh && chmod 600 /home/hexo/.ssh/authorized_keys" 2>/dev/null &&
        ssh -p "$SSH_PORT" -i "$SSH_KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no hexo@localhost "echo SSH连接成功" 2>/dev/null | grep -q "SSH连接成功"
    else
        echo "SSH 密钥不存在: $SSH_KEY_PATH" >&2
        false
    fi'

# 测试 4: Git 仓库初始化测试
run_test "Git仓库初始化测试" "检查 Git 裸仓库是否正确初始化" \
    'docker exec "$CONTAINER_NAME" bash -c "test -d /home/hexo/hexo.git" 2>/dev/null'

# 测试 5: 部署钩子测试
run_test "部署钩子测试" "检查 Git post-receive 钩子是否正确配置" \
    'docker exec "$CONTAINER_NAME" bash -c "test -f /home/hexo/hexo.git/hooks/post-receive && test -x /home/hexo/hexo.git/hooks/post-receive" 2>/dev/null'

# 测试 6: 文件权限测试
run_test "文件权限测试" "检查用户权限和目录访问权限" \
    'docker exec "$CONTAINER_NAME" bash -c "su - hexo -s /bin/bash -c \"whoami && test -w /home/www/hexo\" 2>/dev/null | grep -q hexo"'

# 测试 7: 日志文件权限测试 (v0.0.3 新功能)
run_test "日志文件权限测试" "测试 hexo 用户对部署日志文件的写入权限 (v0.0.3 新功能)" \
    'docker exec "$CONTAINER_NAME" bash -c "if [ ! -f /var/log/container/deployment.log ]; then touch /var/log/container/deployment.log && chown hexo:hexo /var/log/container/deployment.log; fi && ls -la /var/log/container/ | grep deployment.log | awk '\''{print \$3}'\'' | grep -q hexo && su - hexo -s /bin/bash -c '\''echo 测试写入 >> /var/log/container/deployment.log && echo 写入成功'\'' 2>/dev/null | grep -q \"写入成功\""'

# 测试 8: 模拟 Git 部署测试
run_test "模拟Git部署测试" "模拟 Git 推送部署并检查日志生成" \
    'current_dir_before_git_ops_test8="$(pwd)";
    TMP_REPO_PATH_TEST8="/tmp/test8_repo_$$";
    rm -rf "$TMP_REPO_PATH_TEST8";
    mkdir -p "$TMP_REPO_PATH_TEST8";
    cd "$TMP_REPO_PATH_TEST8";
    git init -q -b master;
    git config user.email "test@example.com";
    git config user.name "Test User";
    echo "Test content for Test 8 on $(date)" > test_file.html;
    git add test_file.html;
    git commit -q -m "Commit for Test 8";
    # Ensure authorized_keys is set up in the container for hexo user
    docker exec "'"$CONTAINER_NAME"'" bash -c "mkdir -p /home/hexo/.ssh && echo '\''$(cat "'"$SSH_KEY_PATH.pub"'")'\'' > /home/hexo/.ssh/authorized_keys && chown -R hexo:hexo /home/hexo/.ssh && chmod 600 /home/hexo/.ssh/authorized_keys" >/dev/null 2>&1;
    # Perform the git push
    GIT_SSH_COMMAND="ssh -p '"$SSH_PORT"' -i '\''"'"$SSH_KEY_PATH"'"'\'' -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git push -q ssh://hexo@localhost/home/hexo/hexo.git master -f;
    PUSH_EC=$?;
    if [ $PUSH_EC -eq 0 ]; then
      echo "Git push for Test 8 successful, waiting 3s for hook...";
      sleep 3;
      # Verify deployment log and deployed file content
      docker exec "'"$CONTAINER_NAME"'" bash -c "grep -q '\''=== Git Push Deployment Started ==='\'' /var/log/container/deployment.log && grep -q '\''Files checked out successfully'\'' /var/log/container/deployment.log && test -f /home/www/hexo/test_file.html && grep -q '\''Test content for Test 8 on'\'' /home/www/hexo/test_file.html";
      VERIFY_EC=$?;
      cd "$current_dir_before_git_ops_test8";
      rm -rf "$TMP_REPO_PATH_TEST8";
      exit $VERIFY_EC;
    else
      echo "Git push failed in Test 8 (EC: $PUSH_EC)";
      # For debugging, show verbose SSH output if push fails
      GIT_SSH_COMMAND="ssh -vvv -p '"$SSH_PORT"' -i '\''"'"$SSH_KEY_PATH"'"'\'' -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git push ssh://hexo@localhost/home/hexo/hexo.git master -f;
      cd "$current_dir_before_git_ops_test8";
      rm -rf "$TMP_REPO_PATH_TEST8";
      exit 1;
    fi'

# 测试 9: 日志轮转功能测试 (v0.0.3 新功能)
run_test "日志轮转功能测试" "检查日志轮转功能是否正确配置 (v0.0.3 新功能)" \
    'docker exec "$CONTAINER_NAME" bash -c "grep -q \\\\"rotate_log\\\\" /root/start.sh && grep -q \\\\"check_and_rotate_logs\\\\" /root/start.sh" 2>/dev/null'

# 测试 10: 容器资源使用测试
run_test "容器资源使用测试" "检查容器的 CPU 和内存限制设置" \
    'docker exec "'"$CONTAINER_NAME"'" bash -c "if [ -f /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then cpu_quota=\\\\\$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us); memory_limit=\\\\\$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes); [ \\\\\\"\\\\\\\$cpu_quota\\\\\\" -ne 0 ] && [ \\\\\\"\\\\\\\$memory_limit\\\\\\" -ne 0 ]; else false; fi"'

# 生成测试报告
echo ""
echo "=== 测试总结报告 ==="

PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_TESTS=0

for result in "${TEST_RESULTS[@]}"; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if echo "$result" | grep -q ":PASS:"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
done

SUCCESS_RATE=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc 2>/dev/null || echo "0.0")

echo "总测试数: $TOTAL_TESTS"
echo "通过: $PASSED_TESTS"
echo "失败: $FAILED_TESTS"
echo "成功率: $SUCCESS_RATE%"

# 详细测试结果表格
echo ""
echo "=== 详细测试结果 ==="
printf "%-25s %-8s %-10s\n" "测试名称" "状态" "耗时(s)"
printf "%-25s %-8s %-10s\n" "------------------------" "--------" "----------"

for result in "${TEST_RESULTS[@]}"; do
    IFS=':' read -r test_name status duration <<< "$result"
    printf "%-25s %-8s %-10s\n" "$test_name" "$status" "$duration"
done

# 失败的测试详情
FAILED_TESTS_LIST=()
for result in "${TEST_RESULTS[@]}"; do
    if echo "$result" | grep -q ":FAIL:"; then
        test_name=$(echo "$result" | cut -d: -f1)
        FAILED_TESTS_LIST+=("$test_name")
    fi
done

if [ ${#FAILED_TESTS_LIST[@]} -gt 0 ]; then
    echo ""
    echo "=== 失败的测试 ==="
    for failed_test in "${FAILED_TESTS_LIST[@]}"; do
        echo "❌ $failed_test"
    done
fi

# 保存详细报告到文件
REPORT_CONTENT="=== Hexo Container v0.0.3 功能测试报告 ===
测试时间: $(date)
容器名称: $CONTAINER_NAME
HTTP 端口: $HTTP_PORT
SSH 端口: $SSH_PORT

=== 测试统计 ===
总测试数: $TOTAL_TESTS
通过: $PASSED_TESTS
失败: $FAILED_TESTS
成功率: $SUCCESS_RATE%

=== 详细结果 ===
$(for result in "${TEST_RESULTS[@]}"; do
    IFS=':' read -r test_name status duration <<< "$result"
    echo "$test_name: $status (${duration}s)"
done)

=== v0.0.3 新功能测试状态 ==="

# 查找新功能测试状态
for result in "${TEST_RESULTS[@]}"; do
    if echo "$result" | grep -q "日志文件权限测试"; then
        status=$(echo "$result" | cut -d: -f2)
        echo "日志文件权限测试: $status"
    fi
    if echo "$result" | grep -q "日志轮转功能测试"; then
        status=$(echo "$result" | cut -d: -f2)
        echo "日志轮转功能测试: $status"
    fi
done

REPORT_FILE="$LOG_DIR/functional_test_report_$(date +%Y%m%d_%H%M%S).txt"
echo "$REPORT_CONTENT" > "$REPORT_FILE"

echo ""
echo "详细测试日志: $TEST_LOG"
echo "测试报告: $REPORT_FILE"

# 根据测试结果设置退出代码
if [ $FAILED_TESTS -eq 0 ]; then
    echo ""
    echo "🎉 所有测试通过！"
    exit 0
else
    echo ""
    echo "⚠️ 部分测试失败，请检查详细日志。"
    exit 1
fi
