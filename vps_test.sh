#!/bin/bash
# 动态 VPS 千兆带宽测速脚本
# 支持广州三网、香港本地、国际节点，多线程测速

echo "===== VPS 千兆带宽深度测速 ====="
echo "测试时间: $(date)"
echo "--------------------------------"

# 检查并安装 Speedtest
if ! command -v speedtest &> /dev/null; then
    echo "正在安装 Speedtest CLI..."
    if [ -f /etc/debian_version ]; then
        apt update -y
        apt install -y curl
    elif [ -f /etc/redhat-release ]; then
        yum install -y curl
    fi
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
    apt install -y speedtest
fi

# 获取匹配节点 ID 的函数
get_server_id() {
    speedtest -L | grep -i "$1" | head -n 1 | awk '{print $1}'
}

# 测速函数
run_speedtest () {
    local keyword=$1
    local name=$2
    local id=$(get_server_id "$keyword")
    if [ -n "$id" ]; then
        echo ">>> $name"
        speedtest -s $id --progress=no
        echo "--------------------------------"
    else
        echo ">>> $name"
        echo "找不到可用节点"
        echo "--------------------------------"
    fi
}

# 广州三网
echo "===== 广州三网测速 ====="
run_speedtest "Guangzhou Telecom" "广州电信"
run_speedtest "Guangzhou Unicom" "广州联通"
run_speedtest "Guangzhou Mobile" "广州移动"

# 香港本地
echo "===== 香港本地测速 ====="
run_speedtest "Hong Kong PCCW" "香港 PCCW"
run_speedtest "Hong Kong HGC" "香港 HGC"
run_speedtest "Hong Kong Broadband" "香港 HKBN"

# 国际节点
echo "===== 国际测速 ====="
run_speedtest "Los Angeles" "美国洛杉矶"
run_speedtest "Tokyo" "日本东京"
run_speedtest "Singapore" "新加坡"

echo "===== 测试结束 ====="
echo "说明：千兆口的 Speedtest 峰值应接近 940 Mbps，显著低于此值说明可能是虚标或限速"
