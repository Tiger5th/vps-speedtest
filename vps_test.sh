#!/bin/bash
# VPS 千兆带宽深度测速脚本 (官方二进制直装版)
# 仅下载执行，不依赖系统包管理器，运行完删除

set -e

SPEEDTEST_BIN="/usr/local/bin/speedtest"

install_speedtest() {
    if command -v speedtest >/dev/null 2>&1; then
        echo "检测到已有 speedtest 命令，优先使用系统命令"
        return 0
    fi
    echo ">>> 下载官方 Ookla Speedtest CLI 二进制..."
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH="x86_64"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        ARCH="arm64"
    else
        echo "不支持的架构: $ARCH"
        exit 1
    fi

    TMPDIR=$(mktemp -d)
    curl -sL "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${ARCH}.tgz" -o "$TMPDIR/speedtest.tgz"
    tar -xzf "$TMPDIR/speedtest.tgz" -C "$TMPDIR"
    mv "$TMPDIR/speedtest" "$SPEEDTEST_BIN"
    chmod +x "$SPEEDTEST_BIN"
    rm -rf "$TMPDIR"
    echo "下载并安装完成"
}

run_speedtest() {
    local server_name="$1"
    local server_id

    if command -v speedtest >/dev/null 2>&1; then
        SPEEDTEST_CMD="speedtest"
    else
        SPEEDTEST_CMD="$SPEEDTEST_BIN"
    fi

    server_id=$($SPEEDTEST_CMD --list | grep -i "$server_name" | head -n 1 | awk '{print $1}')
    if [ -n "$server_id" ]; then
        echo ">>> $server_name"
        $SPEEDTEST_CMD --server "$server_id"
    else
        echo ">>> $server_name"
        echo "找不到可用节点"
    fi
    echo "--------------------------------"
}

cleanup() {
    if [ -f "$SPEEDTEST_BIN" ]; then
        echo ">>> 删除临时 speedtest 二进制..."
        rm -f "$SPEEDTEST_BIN"
        echo "删除完成"
    fi
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
    echo "峰值理论约940Mbps，低于明显可能限速或虚标"

    cleanup
}

main
