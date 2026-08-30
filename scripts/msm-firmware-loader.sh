#!/bin/sh
# SPDX-License-Identifier: MIT

# Get the slot suffix for A/B devices.
ab_get_slot() {
    if command -v qbootctl > /dev/null; then
        ab_slot_suffix=$(qbootctl -a 2>/dev/null | grep -o 'Active slot: ..' | cut -d ":" -f2 | xargs) || :
    else
        ab_slot_suffix=$(grep -o 'androidboot\.slot_suffix=..' /proc/cmdline 2>/dev/null | cut -d "=" -f2) || :
    fi
    echo "$ab_slot_suffix"
}

# List of partitions to be mounted and inspected for blobs.
FW_PARTITIONS="
    apnhlos
    bluetooth
    modem$(ab_get_slot)
    persist
"

# Base directory to be used to unfold the partitions into.
BASEDIR="/lib/firmware/msm-firmware-loader"

# 准备 tmpfs 挂载点
mkdir -p "$BASEDIR"
mount -o mode=755,nodev,noexec,nosuid -t tmpfs none "$BASEDIR" 2>/dev/null || true

mkdir -p "$BASEDIR/mnt" "$BASEDIR/target"

# 扫描并挂载固件分区
for part in /sys/block/mmcblk*/mmcblk*p*; do
    [ -d "$part" ] || continue
    DEVNAME="$(grep DEVNAME "$part"/uevent 2>/dev/null | sed 's/DEVNAME=//g')"
    PARTNAME="$(grep PARTNAME "$part"/uevent 2>/dev/null | sed 's/PARTNAME=//g')"

    if [ -n "$PARTNAME" ] && [ -z "${FW_PARTITIONS##*"$PARTNAME"*}" ]; then
        mkdir -p "$BASEDIR/mnt/$PARTNAME"
        mount -o ro,nodev,noexec,nosuid "/dev/$DEVNAME" "$BASEDIR/mnt/$PARTNAME" 2>/dev/null || true
    fi
done

# 链接预置外部路径的固件（如有）
if [ -f /sys/module/firmware_class/parameters/path ]; then
    EXTRA_PATH="$(cat /sys/module/firmware_class/parameters/path 2>/dev/null || true)"
    if [ -n "$EXTRA_PATH" ] && [ -d "$EXTRA_PATH" ]; then
        for blob in "$EXTRA_PATH"/*; do
            [ -e "$blob" ] || continue
            ln -sf "$blob" "$BASEDIR/target/$(basename "$blob")"
        done
    fi
fi

# 扫描挂载分区并链接所有固件 blob
for blob in "$BASEDIR"/mnt/*/image/*; do
    [ -e "$blob" ] || continue
    BLOBBASE="${blob##*/}"
    BLOBBASE="${BLOBBASE%.*}"

    # 如果目标中已有同名前缀的 blob 则跳过
    for prefix in "$BASEDIR/target/$BLOBBASE."*; do
        if [ -e "$prefix" ]; then continue 2; fi
    done

    for part in "$BASEDIR"/mnt/*/image/"$BLOBBASE"*; do
        [ -e "$part" ] || continue
        ln -sf "$part" "$BASEDIR/target/$(basename "$part")"
    done
done

# 提取 persist 分区中的 Wi-Fi 配置文件
if [ -f "$BASEDIR"/mnt/persist/WCNSS_qcom_wlan_nv.bin ]; then
    ln -sf "$BASEDIR"/mnt/persist/WCNSS_qcom_wlan_nv.bin "$BASEDIR"/target/WCNSS_qcom_wlan_nv.bin
fi

# 处理 Venus 视频编解码固件路径
if [ -f "$BASEDIR/target/venus.mdt" ] && ! [ -d "$BASEDIR/target/qcom" ]; then
    mkdir -p "$BASEDIR/target/qcom/venus-x"
    for part in "$BASEDIR"/target/venus.*; do
        [ -e "$part" ] || continue
        ln -sf "$part" "$BASEDIR/target/qcom/venus-x/$(basename "$part")"
    done
fi

VENUS_DIRS="
    venus-1.8
    venus-3.0
    venus-4.2
    venus-4.4
    venus-5.2
    venus-5.4
    vpu-1.0
    vpu-2.0
"

for vdir in $VENUS_DIRS; do
    if ! [ -d "$BASEDIR/target/qcom/$vdir" ] && [ -f "$BASEDIR/target/venus.mdt" ]; then
        ln -sf "$BASEDIR/target/qcom/venus-x" "$BASEDIR/target/qcom/$vdir"
    fi
done

# 重定向 Wi-Fi 配置文件至标准 prima 路径
if [ -e "$BASEDIR"/target/WCNSS_qcom_wlan_nv.bin ]; then
    if ! [ -f "$BASEDIR"/target/wlan/prima/WCNSS_qcom_wlan_nv.bin ]; then
        mkdir -p "$BASEDIR"/target/wlan/prima
        ln -sf "$BASEDIR"/target/WCNSS_qcom_wlan_nv.bin "$BASEDIR"/target/wlan/prima/
    fi
fi

# 处理蓝牙固件 (ath10k / wcn3990)
if [ -d "$BASEDIR"/mnt/bluetooth ]; then
    mkdir -p "$BASEDIR"/target/qca
    for btblob in "$BASEDIR"/mnt/bluetooth/image/*; do
        [ -e "$btblob" ] || continue
        ln -sf "$btblob" "$BASEDIR"/target/qca/
    done
fi

# 为内核兼容性创建 .mbn -> .mdt 软链接
find "$BASEDIR"/target/ -name '*.mdt' -exec sh -c '
    for file do
        target="${file%.mdt}.mbn"
        [ -e "$target" ] || ln -sf "$file" "$target"
    done
' _ {} +

# 设置内核固件加载路径
if [ -w /sys/module/firmware_class/parameters/path ]; then
    printf "%s" "$BASEDIR/target" > /sys/module/firmware_class/parameters/path
fi