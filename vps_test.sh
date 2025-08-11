#!/bin/bash
# VPS 千兆带宽深度测速脚本 (Ookla 官方 CLI 版)
# 作者: Tiger5th 改进 by ChatGPT
# 功能: 自动测速，支持广州三网、香港本地、国际节点，并清理残留

set -e

# 检查并卸载旧版 speedtest-cli (Python 版)
remove_old_speedtest() {
    echo ">>> 检查并卸载旧版 speedtest-cli..."
    if command -v speedtest-cli >/dev/null 2>&1; then
        pip uninstall -y speedtest-cli >/dev/null 2>&1 || true
        apt remove -y speedtest-cli >/dev/null 2>&1 || true
        yum remove -y speedtest-cli >/dev/null 2>&1 || true
    fi
}

# 安装官方 Ookla Speedtest CLI
install_ookla_speedtest() {
    echo ">>> 安装 Ookla Speedtest CLI..."
    if [ -f /etc/debian_version ]; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
        apt-get install -y speedtest
    elif [ -f /etc/redhat-release ]; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | bash
        yum install -y speedtest
    else
        echo "暂不支持的系统，请手动安装官方 Ookla CLI"
        exit 1
    fi
}

# 获取服务器 ID
get_server_id() {
    speedtest --list | grep -i "$1" | head -n 1 | awk '{print $1}'
}

# 测速函数
run_speedtest() {
    local server_name="$1"
    local server_id
    server_id=$(get_server_id "$server_name")
    if [ -n "$server_id" ]; then
        echo ">>> $server_name"
        speedtest --server "$server_id"
    else
        echo ">>> $server_name"
        echo "找不到可用节点"
    fi
    echo "--------------------------------"
}

# 主程序
main() {
    echo "===== VPS 千兆带宽深度测速 ====="
    echo "测试时间: $(date)"
    echo "--------------------------------"

    # 卸载旧版本并安装新版本
    remove_old_speedtest
    install_ookla_speedtest

    echo "===== 广州三网测速 ====="
    run_speedtest "广州 电信"
    run_speedtest "广州 联通"
    run_speedtest "广州 移动"

    echo "===== 香港本地测速 ====="
    run_speedtest "Hong Kong PCCW"
    run_speedtest "Hong Kong HGC"
    run_speedtest "Hong Kong HKBN"

    echo "===== 国际测速 ====="
    run_speedtest "Los Angeles"
    run_speedtest "Tokyo"
    run_speedtest "Singapore"

    echo "===== 测试结束 ====="
    echo "说明：千兆口的 Speedtest 峰值应接近 940 Mbps，显著低于此值说明可能是虚标或限速"

    echo ">>> 清理残留..."
    apt-get remove --purge -y speedtest >/dev/null 2>&1 || yum remove -y speedtest >/dev/null 2>&1
    apt-get autoremove -y >/dev/null 2>&1 || yum autoremove -y >/dev/null 2>&1
    rm -f /etc/apt/sources.list.d/ookla_speedtest-cli.list >/dev/null 2>&1
    rm -rf /var/cache/apt/archives/* /var/cache/yum >/dev/null 2>&1
    echo "所有临时文件和软件已清理完毕。"
}

main
