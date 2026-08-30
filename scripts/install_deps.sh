#!/bin/sh -e

ARCH=$(uname -m)

# 无论什么架构都必须的基础工具包
COMMON_PKGS="
    android-sdk-libsparse-utils
    autoconf
    automake
    cmake
    debian-archive-keyring
    debootstrap
    device-tree-compiler
    fdisk
    gcc-arm-none-eabi
    libtool
    make
    pkg-config
    python3-cryptography
    python3-pyasn1-modules
    python3-pycryptodome
    unzip
    wget
"

apt update

if [ "$ARCH" = "x86_64" ]; then
    echo "Detected x86_64 architecture, installing cross-compilers and QEMU..."
    
    # 动态匹配 QEMU 包名（兼容 Ubuntu 22.04 / 24.04 / 26.04+）
    QEMU_PKG="qemu-user-static"
    if ! apt-cache show "$QEMU_PKG" 2>/dev/null | grep -q '^Package:'; then
        QEMU_PKG="qemu-user-binfmt"
    fi

    apt install -y \
        $COMMON_PKGS \
        $QEMU_PKG \
        binfmt-support \
        g++-aarch64-linux-gnu \
        gcc-aarch64-linux-gnu
else
    echo "Detected native ARM64 architecture ($ARCH), installing native build tools..."
    
    # ARM 机器无需 QEMU 模拟与 aarch64 交叉编译器，直接使用原生编译套件
    apt install -y \
        $COMMON_PKGS \
        build-essential \
        gcc \
        g++
fi