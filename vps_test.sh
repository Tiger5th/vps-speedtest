#!/bin/bash
# VPS 千兆带宽深度测速脚本 (官方二进制版)
# 支持自动下载官方 Speedtest CLI 二进制，测速，结束后清理

set -e

SPEEDTEST_BIN="/usr/local/bin/speedtest"

clean_up() {
    echo ">>> 清理残留..."
    rm -f "$SPEEDTEST_BIN"
    echo "清理完成。"
}

install_speedtest() {
    echo ">>> 下载官方 Ookla Speedtest CLI 二进制..."
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH="x86_64"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        ARCH="arm64"
    else
        echo "暂不支持此架构: $ARCH"
        exit 1
    fi

    TMPDIR=$(mktemp -d)
    curl -sL "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${ARCH}.tgz" -o "$TMPDIR/speedtest.tgz"
    tar -xzf "$TMPDIR/speedtest.tgz" -C "$TMPDIR"
    mv "$TMPDIR/speedtest" "$SPEEDTEST_BIN"
    chmod +x "$SPEEDTEST_BIN"
    rm -rf "$TMPDIR"
    echo "安装完成。"
}

get_server_id() {
    "$SPEEDTEST_BIN" --list | grep -i "$1" | head -n 1 | awk '{print $1}'
}

run_speedtest() {
    local server_name="$1"
    local server_id
    server_id=$(get_server_id "$server_name")
    if [ -n "$server_id" ]; then
        echo ">>> $server_name"
        "$SPEEDTEST_BIN" --server "$server_id"
    else
        echo ">>> $server_name"
        echo "找不到可用节点"
    fi
    echo "--------------------------------"
}

main() {
    echo "===== VPS 千兆带宽深度测速 ====="
    echo "测试时间: $(date)"
    echo "--------------------------------"

    install_speedtest

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

    clean_up
}

main
