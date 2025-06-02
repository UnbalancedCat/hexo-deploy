#!/bin/bash
# 镜像源自动选择脚本
# Mirror Source Auto Selection Script
# 
# 此脚本将测试多个Ubuntu镜像源的连通性，并选择最快的源

# 定义镜像源列表
declare -A MIRRORS=(
    ["tsinghua"]="https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
    ["aliyun"]="https://mirrors.aliyun.com/ubuntu"
    ["huawei"]="https://mirrors.huaweicloud.com/ubuntu"
    ["ustc"]="https://mirrors.ustc.edu.cn/ubuntu"
    ["163"]="https://mirrors.163.com/ubuntu"
    ["sjtu"]="https://mirror.sjtu.edu.cn/ubuntu"
    ["official"]="http://archive.ubuntu.com/ubuntu"
)

# 测试镜像源连通性和速度
test_mirror() {
    local name=$1
    local url=$2
    local test_file="ls-lR.gz"
    
    echo "测试镜像源: $name ($url)"
    
    # 测试连通性
    if ! curl -s --connect-timeout 5 --max-time 10 "$url/dists/jammy/Release" > /dev/null 2>&1; then
        echo "  [FAIL] 连接失败"
        return 1
    fi
    
    # 测试下载速度 (下载少量数据)
    local start_time=$(date +%s.%N)
    if curl -s --connect-timeout 5 --max-time 10 "$url/dists/jammy/Release" > /dev/null 2>&1; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        echo "  [SUCCESS] 响应时间: ${duration}s"
        echo "$duration:$name:$url"
        return 0
    else
        echo "  [FAIL] 下载测试失败"
        return 1
    fi
}

# 选择最佳镜像源
select_best_mirror() {
    echo "=== Ubuntu 镜像源连通性测试 ==="
    echo
    
    local results=()
    local temp_file="/tmp/mirror_test_results.txt"
    > "$temp_file"
    
    # 测试所有镜像源
    for name in "${!MIRRORS[@]}"; do
        url="${MIRRORS[$name]}"
        if result=$(test_mirror "$name" "$url"); then
            if [[ $result =~ ^[0-9] ]]; then
                echo "$result" >> "$temp_file"
            fi
        fi
        echo
    done
    
    # 选择最快的镜像源
    if [ -s "$temp_file" ]; then
        local best_line=$(sort -n "$temp_file" | head -n1)
        local best_time=$(echo "$best_line" | cut -d: -f1)
        local best_name=$(echo "$best_line" | cut -d: -f2)
        local best_url=$(echo "$best_line" | cut -d: -f3)
        
        echo "=== 最佳镜像源选择结果 ==="
        echo "名称: $best_name"
        echo "URL: $best_url"
        echo "响应时间: ${best_time}s"
        echo
        
        # 生成 sources.list 内容
        generate_sources_list "$best_url"
        
        rm -f "$temp_file"
        return 0
    else
        echo "错误: 没有可用的镜像源"
        rm -f "$temp_file"
        return 1
    fi
}

# 生成 sources.list 内容
generate_sources_list() {
    local mirror_url=$1
    local sources_file="/tmp/sources.list.optimized"
    
    cat > "$sources_file" << EOF
# 优化的 Ubuntu 22.04 (Jammy) 镜像源配置
# 自动选择的最佳镜像源: $mirror_url

deb $mirror_url jammy main restricted universe multiverse
deb $mirror_url jammy-updates main restricted universe multiverse
deb $mirror_url jammy-backports main restricted universe multiverse
deb $mirror_url jammy-security main restricted universe multiverse

# 源码包 (可选)
# deb-src $mirror_url jammy main restricted universe multiverse
# deb-src $mirror_url jammy-updates main restricted universe multiverse
# deb-src $mirror_url jammy-backports main restricted universe multiverse
# deb-src $mirror_url jammy-security main restricted universe multiverse
EOF

    echo "已生成优化的 sources.list 文件: $sources_file"
    echo "内容如下:"
    echo "----------------------------------------"
    cat "$sources_file"
    echo "----------------------------------------"
    echo
    echo "使用方法:"
    echo "1. 在 Dockerfile 中添加:"
    echo "   COPY sources.list.optimized /etc/apt/sources.list"
    echo "2. 或者在构建时复制:"
    echo "   cp $sources_file /etc/apt/sources.list"
}

# 主执行函数
main() {
    echo "Ubuntu 镜像源自动优化工具"
    echo "========================="
    echo
    
    # 检查必要的工具
    if ! command -v curl &> /dev/null; then
        echo "错误: 需要安装 curl"
        echo "Ubuntu/Debian: apt-get install curl"
        echo "CentOS/RHEL: yum install curl"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        echo "警告: 建议安装 bc 以获得精确的时间测量"
        echo "Ubuntu/Debian: apt-get install bc"
    fi
    
    # 执行镜像源选择
    if select_best_mirror; then
        echo "镜像源优化完成!"
        echo "建议将生成的 sources.list 文件应用到您的 Dockerfile 中"
    else
        echo "镜像源优化失败!"
        echo "请检查网络连接或手动配置镜像源"
        exit 1
    fi
}

# 执行主函数
main "$@"
