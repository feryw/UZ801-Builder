#!/bin/sh -e

ARCH=$(uname -m)

# 1. 动态设置 qhypstub 的编译器前缀
if [ "$ARCH" = "x86_64" ]; then
    CROSS_COMPILE="aarch64-linux-gnu-"
else
    CROSS_COMPILE=""
fi

echo "Building qhypstub..."
make -C src/qhypstub CROSS_COMPILE="${CROSS_COMPILE}"

# 2. 安全追加 MMC 降速补丁（避免本地多次执行重复追加）
MK_FILE="src/lk2nd/project/lk1st-msm8916.mk"
if ! grep -q "USE_TARGET_HS200_CAPS=1" "$MK_FILE"; then
    echo 'DEFINES += USE_TARGET_HS200_CAPS=1' >> "$MK_FILE"
fi

# 3. 编译 lk2nd（32 位 ARM 裸机程序，双架构通用）
echo "Building lk2nd..."
make -C src/lk2nd LK2ND_BUNDLE_DTB="msm8916-512mb-mtp.dtb" LK2ND_COMPATIBLE="yiming,uz801-v3" \
    TOOLCHAIN_PREFIX=arm-none-eabi- lk1st-msm8916 -j$(nproc)

# 4. 签名并输出固件
echo "Signing binaries..."
mkdir -p files
python3 src/qtestsign/qtestsign.py hyp src/qhypstub/qhypstub.elf \
    -o files/hyp.mbn
python3 src/qtestsign/qtestsign.py aboot src/lk2nd/build-lk1st-msm8916/emmc_appsboot.mbn \
    -o files/aboot.mbn

echo "Hyp and aboot built successfully."