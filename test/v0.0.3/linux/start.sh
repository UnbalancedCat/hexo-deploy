#!/bin/bash

# Docker Hexo Static Blog v0.0.3 - Linux Complete Test Suite Startup Script
# 完整测试套件启动脚本

# set -e  # Re-enabled for production use

# 颜色定义 (Corrected for echo -e and printf)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置参数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
DOCKERFILE_DIR="$(cd "$SCRIPT_DIR/../../../" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
# SUITE_LOG is defined in main after mkdir -p LOG_DIR

# 测试脚本数组
TESTS=(
    "build_test.sh:构建测试"
    "run_test.sh:运行测试"
    "functional_test.sh:功能测试"
    "log_rotation_test.sh:日志轮转测试"
    "cleanup_test.sh:清理测试"
)

# 函数：显示横幅
show_banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║                Docker Hexo Static Blog v0.0.3                ║"
    echo "  ║                     完整测试套件 (Linux)                     ║"
    echo "  ║                                                              ║"
    echo "  ║  • 自动化构建和部署测试                                      ║"
    echo "  ║  • 功能完整性验证                                            ║"
    echo "  ║  • 日志轮转和权限测试                                        ║"
    echo "  ║  • 安全配置验证                                              ║"
    echo "  ║  • 性能监控                                                  ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 函数：记录日志
log() {
    echo -e "${BLUE}[$(LC_ALL=C date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$SUITE_LOG"
    local tee_status=${PIPESTATUS[1]}
    if [ $tee_status -ne 0 ]; then
        echo -e "${RED}CRITICAL: tee in log failed (status $tee_status) writing to $SUITE_LOG${NC}" >&2
    fi
    return 0
}

log_success() {
    echo -e "${GREEN}[$(LC_ALL=C date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $1" | tee -a "$SUITE_LOG"
    local tee_status=${PIPESTATUS[1]}
    if [ $tee_status -ne 0 ]; then
        echo -e "${RED}CRITICAL: tee in log_success failed (status $tee_status) writing to $SUITE_LOG${NC}" >&2
    fi
    return 0
}

log_error() {
    echo -e "${RED}[$(LC_ALL=C date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $1" | tee -a "$SUITE_LOG"
    local tee_status=${PIPESTATUS[1]}
    if [ $tee_status -ne 0 ]; then
        # Avoid using log_error here to prevent recursion if SUITE_LOG is the problem
        echo -e "${RED}CRITICAL: tee in log_error failed (status $tee_status) writing to $SUITE_LOG${NC}" >&2
    fi
    return 0
}

log_warning() {
    echo -e "${YELLOW}[$(LC_ALL=C date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $1" | tee -a "$SUITE_LOG"
    local tee_status=${PIPESTATUS[1]}
    if [ $tee_status -ne 0 ]; then
        echo -e "${RED}CRITICAL: tee in log_warning failed (status $tee_status) writing to $SUITE_LOG${NC}" >&2
    fi
    return 0
}

log_step() {
    echo -e "${CYAN}[$(LC_ALL=C date '+%Y-%m-%d %H:%M:%S')] ▶${NC} $1" | tee -a "$SUITE_LOG"
    local tee_status=${PIPESTATUS[1]}
    if [ $tee_status -ne 0 ]; then
        echo -e "${RED}CRITICAL: tee in log_step failed (status $tee_status) writing to $SUITE_LOG${NC}" >&2
    fi
    return 0
}

# 函数：显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}进度: [${NC}" # Corrected format string
    printf "%*s" "$filled" | tr ' ' '=' # Corrected tr command and quoted variable
    printf "%*s" "$empty" | tr ' ' ' ' # Corrected tr command and quoted variable
    printf "${CYAN}] %d%% (%d/%d)${NC}" "$percentage" "$current" "$total" # Quoted variables
}

# 函数：检查前置条件
check_prerequisites() {
    log_step "检查测试前置条件..."
    
    local errors=0
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装或不在 PATH 中"
        ((errors++))
    fi
    
    # 检查 Docker 服务
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行"
        ((errors++))
    fi
    
    # 检查 Dockerfile
    if [ ! -f "$DOCKERFILE_DIR/Dockerfile_v0.0.3" ]; then
        log_error "Dockerfile_v0.0.3 不存在于 $DOCKERFILE_DIR"
        ((errors++))
    fi
    
    # 检查测试脚本
    for test_info in "${TESTS[@]}"; do
        script_name="${test_info%%:*}"
        if [ ! -f "$SCRIPT_DIR/$script_name" ]; then
            log_error "测试脚本不存在: $script_name"
            ((errors++))
        elif [ ! -x "$SCRIPT_DIR/$script_name" ]; then
            log_warning "测试脚本没有执行权限: $script_name (将自动修复)"
            chmod +x "$SCRIPT_DIR/$script_name"
        fi
    done
    
    if [ $errors -gt 0 ]; then
        log_error "发现 $errors 个前置条件问题，无法继续测试"
        exit 1 # Exit if prerequisites fail
    fi
    
    log_success "前置条件检查通过"
}

# 函数：准备测试环境
prepare_test_environment() {
    log_step "准备测试环境..."
    
    # 创建日志目录 (already created in main, but ensure it)
    mkdir -p "$LOG_DIR"
    
    # 清理旧的测试资源（可选）
    if [ "${CLEAN_START:-false}" = "true" ]; then
        log "清理旧的测试资源..."
        # Allow these commands to fail without exiting the script immediately
        docker stop hexo-blog-test 2>/dev/null || true
        docker rm hexo-blog-test 2>/dev/null || true
        docker rmi hexo-test:v0.0.3 2>/dev/null || true # Ensure correct image name used elsewhere
    fi
    
    # 设置测试脚本权限
    chmod +x "$SCRIPT_DIR"/*.sh
    
    log_success "测试环境准备完成"
}

# 函数：运行单个测试
run_test() {
    local test_info="$1"
    local script_name="${test_info%%:*}"
    local test_description="${test_info##*:}"
    
    log_step "执行测试: $test_description ($script_name)"
    
    local test_log="$LOG_DIR/${script_name%.sh}.log"
    local start_time
    start_time=$(LC_ALL=C date +%s)
    
    # 执行测试脚本
    # The actual script ($script_name) should handle its own set -e behavior.
    # If it fails, its non-zero exit code will be caught here.
    if LC_ALL=C bash "$SCRIPT_DIR/$script_name" > "$test_log" 2>&1; then
        local end_time
        end_time=$(LC_ALL=C date +%s)
        local duration=$((end_time - start_time))
        log_success "$test_description 测试通过 (耗时: ${duration}s)"
        return 0 # Test script succeeded
    else
        local exit_code=$? # Capture exit code of the failing script
        local end_time
        end_time=$(LC_ALL=C date +%s)
        local duration=$((end_time - start_time))
        log_error "$test_description 测试失败 (退出码: $exit_code, 耗时: ${duration}s)"
        log_error "详细日志: $test_log"
        
        # 显示失败的最后几行
        echo -e "${RED}错误详情 (最后10行):${NC}"
        tail -10 "$test_log" | sed \'s/^/  /\' # Ensure sed doesn\'t cause issues
        
        return 1 # Test script failed
    fi
}

# 函数：运行所有测试
run_all_tests() {
    log_step "开始执行完整测试套件..."
    
    local total_tests=${#TESTS[@]}
    local passed_tests=0
    local failed_tests=0
    local suite_start_time
    suite_start_time=$(LC_ALL=C date +%s)
    
    echo "" # Newline before progress
    
    for i in "${!TESTS[@]}"; do
        local current=$((i + 1))
        show_progress $current $total_tests
        echo "" # Newline after progress bar, before test execution logs
        
        if run_test "${TESTS[$i]}"; then
            ((passed_tests++))
        else
            ((failed_tests++))
            if [ "${CONTINUE_ON_FAILURE:-true}" = "true" ]; then # Default to true
                log_warning "测试失败，但继续执行剩余测试..."
            else
                log_error "测试失败，停止执行"
                break # Exit loop
            fi
        fi
        echo "" # Newline after test result
    done
    
    local suite_end_time
    suite_end_time=$(LC_ALL=C date +%s)
    local total_duration=$((suite_end_time - suite_start_time))
    
    # Final progress update to 100% if all tests run
    if [ $failed_tests -eq 0 ] || [ "${CONTINUE_ON_FAILURE:-true}" = "true" ]; then
        show_progress $total_tests $total_tests
        echo "" # Newline after final progress
    fi
    
    echo ""
    log_step "测试套件执行完成"
    log "总耗时: ${total_duration}s"
    log "通过测试: $passed_tests/$total_tests"
    log "失败测试: $failed_tests/$total_tests"
    
    # 生成测试报告
    generate_test_report $passed_tests $failed_tests $total_duration
    
    if [ $failed_tests -eq 0 ]; then
        log_success "所有测试都通过了！🎉"
        return 0 # Overall success
    else
        log_error "有 $failed_tests 个测试失败"
        return 1 # Overall failure
    fi
}

# 函数：生成测试报告
generate_test_report() {
    local passed=$1
    local failed=$2
    local duration=$3
    local total=$((passed + failed))
    local success_rate=0
    if [ $total -gt 0 ]; then
        success_rate=$(( passed * 100 / total ))
    fi

    local report_file="$LOG_DIR/test_suite_report.txt"
    
    log_step "生成测试报告..."
    
    # Use cat with explicit EOF marker
    cat > "$report_file" <<-EOF
Docker Hexo Static Blog v0.0.3 - 完整测试套件报告 (Linux)
========================================================

测试时间: $(LC_ALL=C date)
测试环境: Linux ($(uname -r))
Docker 版本: $(docker --version)
测试位置: $SCRIPT_DIR

测试结果概要:
- 总测试数: $total
- 通过测试: $passed
- 失败测试: $failed
- 成功率: $success_rate%
- 总耗时: ${duration}s

详细测试结果:
EOF
    
    for test_info in "${TESTS[@]}"; do
        local script_name="${test_info%%:*}"
        local test_description="${test_info##*:}"
        local test_log_file="$LOG_DIR/${script_name%.sh}.log" # Renamed to avoid conflict
        
        echo "- $test_description:" >> "$report_file"
        if [ -f "$test_log_file" ]; then
            # Check for success markers more robustly
            # Assuming test scripts output specific success strings or exit 0
            # For now, rely on the run_test logic that populates passed/failed counts
            # This report section can be enhanced if tests output specific markers
            if grep -q -E "SUCCESS|成功|✓|测试通过" "$test_log_file" 2>/dev/null || \
               ( [ -s "$test_log_file" ] && ! grep -q -E "FAIL|失败|✗|测试失败" "$test_log_file" 2>/dev/null && \
                 grep -q "构建成功" "$test_log_file" 2>/dev/null ) ; then # Example for build_test
                echo "  状态: ✓ 通过" >> "$report_file"
            elif grep -q -E "FAIL|失败|✗|测试失败" "$test_log_file" 2>/dev/null; then
                 echo "  状态: ✗ 失败" >> "$report_file"
            else
                 # If log exists but no clear pass/fail, mark as indeterminate or check exit code if stored
                 echo "  状态: ? 结果未知 (检查日志)" >> "$report_file"
            fi
            echo "  日志: $test_log_file" >> "$report_file"
        else
            echo "  状态: ? 未执行或日志丢失" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done
    
    # 添加系统信息
    echo "系统信息:" >> "$report_file"
    echo "- 操作系统: $(uname -s)" >> "$report_file"
    echo "- 内核版本: $(uname -r)" >> "$report_file"
    echo "- 架构: $(uname -m)" >> "$report_file"
    # Ensure free and df commands don't fail due to locale
    echo "- 可用内存: $(LC_ALL=C free -h | grep '^Mem:' | awk '{print $7}')" >> "$report_file"
    echo "- 磁盘空间: $(LC_ALL=C df -h . | tail -1 | awk '{print $4}')" >> "$report_file"
    
    log_success "测试报告已生成: $report_file"
}

# 函数：显示帮助信息
show_help() {
    cat <<-EOF
Docker Hexo Static Blog v0.0.3 - Linux 完整测试套件

用法: $0 [选项]

选项:
  --help, -h              显示此帮助信息
  --clean-start           清理旧资源后开始测试 (设置 CLEAN_START=true)
  --stop-on-failure       第一个测试失败时停止 (设置 CONTINUE_ON_FAILURE=false)
  --list                  列出所有可用的测试
  --test <script_name>    只运行指定的测试脚本 (例如: build_test.sh)
  --report-only           只生成报告，不运行测试 (需要现有日志)

环境变量:
  CLEAN_START=true        等同于 --clean-start
  CONTINUE_ON_FAILURE=false 等同于 --stop-on-failure

示例:
  $0                     # 运行完整测试套件
  $0 --clean-start       # 清理后运行测试
  $0 --test build_test.sh # 只运行构建测试

测试脚本:
EOF
    
    for test_info in "${TESTS[@]}"; do
        local script_name="${test_info%%:*}"
        local test_description="${test_info##*:}"
        printf "  %-25s %s\\n" "$script_name" "$test_description"
    done
}

# 函数：列出测试
list_tests() {
    echo "可用的测试脚本:"
    echo ""
    for i in "${!TESTS[@]}"; do
        local test_info="${TESTS[$i]}"
        local script_name="${test_info%%:*}"
        local test_description="${test_info##*:}"
        printf "%d. %-25s - %s\\n" $((i + 1)) "$script_name" "$test_description"
    done
}

# 函数：运行单个指定测试
run_single_test() {
    local target_script="$1"
    
    # Find the test_info for the target_script
    local found_test_info=""
    for test_info_item in "${TESTS[@]}"; do
        local script_name_item="${test_info_item%%:*}"
        if [ "$script_name_item" = "$target_script" ]; then
            found_test_info="$test_info_item"
            break
        fi
    done
    
    if [ -z "$found_test_info" ]; then
        log_error "未找到测试脚本: $target_script"
        echo "可用的测试脚本:"
        list_tests # Call list_tests function
        return 1
    fi

    # Prepare environment for single test run
    # Note: SUITE_LOG might not be set if main() isn't fully run.
    # For simplicity, single test runs will log to their own file and console.
    # More robust single test logging would require initializing SUITE_LOG.
    mkdir -p "$LOG_DIR" # Ensure log dir exists
    export SUITE_LOG="$LOG_DIR/single_test_run_$(date +%Y%m%d_%H%M%S).log" # Temporary suite log for this run
    echo "Running single test: $target_script. Main log: $SUITE_LOG" > "$SUITE_LOG"


    log_step "运行单个测试: $target_script"
    # check_prerequisites # Optional: run for single test
    prepare_test_environment # Run prepare, it handles CLEAN_START
    
    run_test "$found_test_info"
    local test_exit_code=$?
    
    if [ $test_exit_code -eq 0 ]; then
        log_success "$target_script 测试通过"
    else
        log_error "$target_script 测试失败"
    fi
    return $test_exit_code
}

# 主函数
main() {
    # Ensure LOG_DIR exists before SUITE_LOG is defined
    mkdir -p "$LOG_DIR"
    # Define SUITE_LOG here so all log functions can use it
    # This was previously in the parameter parsing block for main call
    export SUITE_LOG="$LOG_DIR/test_suite_$(LC_ALL=C date +%Y%m%d_%H%M%S).log"

    show_banner
    
    log "Docker Hexo Static Blog v0.0.3 完整测试套件启动"
    log "================================================"
    log "脚本位置: $SCRIPT_DIR"
    log "Dockerfile 位置: $DOCKERFILE_DIR"
    log "日志位置: $LOG_DIR (主套件日志: $SUITE_LOG)"
    
    check_prerequisites
    prepare_test_environment # Handles CLEAN_START logic
    run_all_tests
    # run_all_tests returns 0 for all pass, 1 for any failure
    return $? # Propagate the exit status of run_all_tests
}

# --- Main script execution starts here ---

# Default behavior: continue on failure
export CONTINUE_ON_FAILURE="${CONTINUE_ON_FAILURE:-true}"
# Default behavior: don't clean start unless specified
export CLEAN_START="${CLEAN_START:-false}"


# Argument parsing
if [ $# -eq 0 ]; then
    main
    exit $? # Exit with main's status
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --list)
            list_tests
            exit 0
            ;;
        --clean-start)
            export CLEAN_START=true
            # If it's the only arg, run main. If others follow, they'll be processed.
            shift
            if [ $# -eq 0 ]; then main; exit $?; fi
            ;;
        --stop-on-failure)
            export CONTINUE_ON_FAILURE=false
            shift
            if [ $# -eq 0 ]; then main; exit $?; fi
            ;;
        --test)
            if [ -z "$2" ]; then
                # Temporarily set SUITE_LOG for this error message if not already set
                export SUITE_LOG="${SUITE_LOG:-$LOG_DIR/error_$(date +%Y%m%d_%H%M%S).log}"
                mkdir -p "$(dirname "$SUITE_LOG")"
                log_error "请指定要运行的测试脚本名称 (例如: build_test.sh)"
                show_help
                exit 1
            fi
            run_single_test "$2"
            exit $? # Exit with single test's status
            ;;
        --report-only)
             # Ensure SUITE_LOG is defined for logging within generate_test_report
            export SUITE_LOG="${SUITE_LOG:-$LOG_DIR/report_only_$(date +%Y%m%d_%H%M%S).log}"
            mkdir -p "$(dirname "$SUITE_LOG")"
            if [ -d "$LOG_DIR" ] && [ "$(find "$LOG_DIR" -name \'*.log\' -print -quit)" ]; then
                # Dummy values for passed/failed/duration as we are only generating report from existing logs
                generate_test_report 0 0 0
                exit $?
            else
                log_error "没有找到测试日志目录 $LOG_DIR 或日志文件以生成报告。"
                exit 1
            fi
            ;;
        *)
            # If main hasn't run yet due to options, run it now.
            # This handles the case where options like --clean-start are given,
            # and then the script is expected to run the full suite.
            if ! ps -p $$ -o comm= | grep -q "start.sh"; then # Basic check if main was already invoked
                 main
                 exit $?
            else
                # If options were processed and we still have an unknown one, it's an error.
                export SUITE_LOG="${SUITE_LOG:-$LOG_DIR/error_$(date +%Y%m%d_%H%M%S).log}"
                mkdir -p "$(dirname "$SUITE_LOG")"
                log_error "未知参数: $1"
                show_help
                exit 1
            fi
            ;;
    esac
    # shift # Shift only if argument was consumed and not an exit/main call
done

# If loop finishes and main hasn't been called (e.g. only options like --clean-start were set)
# This logic might be complex depending on desired option interactions.
# A common pattern is to set flags and have one call to main() at the end.
# The current structure calls main or exits within the case statement for most paths.
# If we reach here, it implies options were processed that set flags, and now main should run.
if [ "${#BASH_SOURCE[@]}" -eq 1 ] && [ -z "${_MAIN_CALLED_VIA_OPTIONS:-}" ]; then
    # Check if main was called by an option that then shifted out all args
    # This is a fallback if options like --clean-start are given,
    # and the parameter parsing was modified to call main if --clean-start is the only arg.
    # So this path might not be strictly needed anymore.
    : # Do nothing, main should have been called or script exited.
fi

# Final exit status should be from main or specific option handlers.
# Bash scripts exit with the status of the last command if not specified.
# The explicit `exit $?` after main calls ensures this.
