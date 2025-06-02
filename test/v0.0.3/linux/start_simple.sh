#!/bin/bash

# Docker Hexo Static Blog v0.0.3 - Linux Complete Test Suite Startup Script (Simplified)
# 完整测试套件启动脚本 (简化版)

# 配置参数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
DOCKERFILE_DIR="$(cd "$SCRIPT_DIR/../../../" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

# 测试脚本数组
TESTS=(
    "build_test.sh"
    "run_test.sh"
    "functional_test.sh"
    "log_rotation_test.sh"
    "cleanup_test.sh"
)

# 创建日志目录
mkdir -p "$LOG_DIR"
SUITE_LOG="$LOG_DIR/test_suite_$(date +%Y%m%d_%H%M%S).log"

echo "=== Docker Hexo Static Blog v0.0.3 - Linux 完整测试套件 ===" | tee "$SUITE_LOG"
echo "开始时间: $(date)" | tee -a "$SUITE_LOG"
echo "脚本位置: $SCRIPT_DIR" | tee -a "$SUITE_LOG"
echo "Dockerfile 位置: $DOCKERFILE_DIR" | tee -a "$SUITE_LOG"
echo "日志位置: $LOG_DIR" | tee -a "$SUITE_LOG"
echo "" | tee -a "$SUITE_LOG"

# 清理旧资源（如果指定）
if [ "${1:-}" = "--clean-start" ]; then
    echo "清理旧的测试资源..." | tee -a "$SUITE_LOG"
    docker stop hexo-test-v003 2>/dev/null || true
    docker rm hexo-test-v003 2>/dev/null || true
    docker rmi hexo-test:v0.0.3 2>/dev/null || true
fi

# 设置测试脚本权限
chmod +x "$SCRIPT_DIR"/*.sh

# 运行测试
passed_tests=0
failed_tests=0
total_tests=${#TESTS[@]}

for i in "${!TESTS[@]}"; do
    current=$((i + 1))
    script_name="${TESTS[$i]}"
    
    echo "[$current/$total_tests] 运行测试: $script_name" | tee -a "$SUITE_LOG"
    
    test_log="$LOG_DIR/${script_name%.sh}_$(date +%Y%m%d_%H%M%S).log"
    
    # 运行测试脚本
    if bash "$SCRIPT_DIR/$script_name" > "$test_log" 2>&1; then
        echo "✓ $script_name 测试通过" | tee -a "$SUITE_LOG"
        ((passed_tests++))
    else
        echo "✗ $script_name 测试失败" | tee -a "$SUITE_LOG"
        echo "  详细日志: $test_log" | tee -a "$SUITE_LOG"
        echo "  最后10行错误:" | tee -a "$SUITE_LOG"
        tail -10 "$test_log" | sed 's/^/    /' | tee -a "$SUITE_LOG"
        ((failed_tests++))
        
        # 默认继续执行其他测试
        if [ "${CONTINUE_ON_FAILURE:-true}" != "true" ]; then
            echo "测试失败，停止执行" | tee -a "$SUITE_LOG"
            break
        fi
    fi
    echo "" | tee -a "$SUITE_LOG"
done

# 生成最终报告
echo "=== 测试套件执行完成 ===" | tee -a "$SUITE_LOG"
echo "结束时间: $(date)" | tee -a "$SUITE_LOG"
echo "通过测试: $passed_tests/$total_tests" | tee -a "$SUITE_LOG"
echo "失败测试: $failed_tests/$total_tests" | tee -a "$SUITE_LOG"

if [ $failed_tests -eq 0 ]; then
    echo "🎉 所有测试都通过了！" | tee -a "$SUITE_LOG"
    exit 0
else
    echo "❌ 有 $failed_tests 个测试失败" | tee -a "$SUITE_LOG"
    exit 1
fi
