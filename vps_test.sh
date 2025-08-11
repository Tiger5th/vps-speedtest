#!/bin/bash
set -e

echo "===== VPS 带宽测试脚本 ====="
echo "测试时间: $(date)"
echo "--------------------------------"

# 判断speedtest版本是否支持--list
check_speedtest() {
    if command -v speedtest >/dev/null 2>&1; then
        # 测试是否支持 --list
        if speedtest --help | grep -- --list >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# 安装 fast CLI (Netflix)
install_fast() {
    echo ">>> 安装 fast CLI (Netflix测速工具)..."
    if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
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
        curl -sL "https://github.com/fast-run/fast/releases/latest/download/fast-linux-${ARCH}.tar.gz" -o "$TMPDIR/fast.tar.gz"
        tar -xzf "$TMPDIR/fast.tar.gz" -C "$TMPDIR"
        chmod +x "$TMPDIR/fast"
        mv "$TMPDIR/fast" /usr/local/bin/fast
        rm -rf "$TMPDIR"
        echo "fast 安装完成"
    else
        echo "缺少 curl 或 tar，无法安装 fast"
        exit 1
    fi
}

# 测试函数，使用speedtest（无服务器选择）
run_speedtest_simple() {
    echo ">>> 使用 speedtest 进行测速..."
    speedtest --accept-license --accept-gdpr
}

# 测试函数，使用 fast
run_fast() {
    echo ">>> 使用 fast CLI 进行测速..."
    fast
}

main() {
    if check_speedtest; then
        echo "检测到支持 --list 的 speedtest，运行完整版测速..."

        # 以下简化版，避免--list找服务器不稳定，直接测速默认服务器
        run_speedtest_simple

    else
        echo "speedtest 不支持 --list 或未安装"

        if ! command -v fast >/dev/null 2>&1; then
            install_fast
        fi

        run_fast
    fi

    echo "===== 测试结束 ====="
}

main
