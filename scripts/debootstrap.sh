#!/bin/sh -e

CHROOT=${CHROOT:-$(pwd)/rootfs}
RELEASE=${RELEASE:-stable}
HOST_NAME=${HOST_NAME:-openstick-debian}
ARCH=$(uname -m)

# 1. 预清理：如果存在残留挂载先递归强制卸载，再安全删除
if [ -d "${CHROOT}" ]; then
    echo "Cleaning up old rootfs mount points and directory..."
    umount -l -R "${CHROOT}" 2>/dev/null || true
    rm -rf "${CHROOT}"
fi

# 2. 注册异常中断清理陷阱
cleanup_mounts() {
    for a in proc sys dev/pts dev run; do
        umount -l "${CHROOT}/${a}" 2>/dev/null || true
    done
}
trap cleanup_mounts EXIT INT TERM

# 3. 根据宿主机架构执行 debootstrap
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "Running native ARM64 debootstrap (single stage)..."
    debootstrap --arch arm64 \
        --keyring /usr/share/keyrings/debian-archive-keyring.gpg "${RELEASE}" "${CHROOT}"
    CHROOT_PREFIX=""
else
    echo "Running cross-architecture debootstrap with QEMU..."
    debootstrap --foreign --arch arm64 \
        --keyring /usr/share/keyrings/debian-archive-keyring.gpg "${RELEASE}" "${CHROOT}"
    
    QEMU_BIN=$(which qemu-aarch64-static 2>/dev/null || which qemu-arm-static 2>/dev/null || echo "/usr/bin/qemu-aarch64-static")
    cp "$QEMU_BIN" "${CHROOT}/usr/bin/"
    chroot "${CHROOT}" qemu-aarch64-static /bin/bash /debootstrap/debootstrap --second-stage
    CHROOT_PREFIX="qemu-aarch64-static"
fi

# 4. 配置 APT 源
cat << EOF > "${CHROOT}/etc/apt/sources.list"
deb http://deb.debian.org/debian ${RELEASE} main contrib non-free-firmware
deb http://deb.debian.org/debian-security/ ${RELEASE}-security main contrib non-free-firmware
deb http://deb.debian.org/debian ${RELEASE}-updates main contrib non-free-firmware
EOF

# 5. 挂载宿主机虚拟文件系统
mount -t proc proc "${CHROOT}/proc/"
mount -t sysfs sys "${CHROOT}/sys/"
mount -o bind /dev/ "${CHROOT}/dev/"
mount -o bind /dev/pts/ "${CHROOT}/dev/pts/"
mount -o bind /run "${CHROOT}/run/"

# 6. 执行内部 setup 脚本
cp scripts/setup.sh "${CHROOT}"
chroot "${CHROOT}" ${CHROOT_PREFIX} /bin/sh -c /setup.sh

# 7. 主动卸载并解除 trap
cleanup_mounts
trap - EXIT INT TERM

rm -f "${CHROOT}/setup.sh"
echo -n > "${CHROOT}/root/.bash_history"

# 8. 配置主机名
echo "${HOST_NAME}" > "${CHROOT}/etc/hostname"
sed -i "/localhost/ s/$/ ${HOST_NAME}/" "${CHROOT}/etc/hosts"

# 9. 安装 systemd 服务与 firmware loader
cp -a configs/system/* "${CHROOT}/etc/systemd/system"
cp -a scripts/msm-firmware-loader.sh "${CHROOT}/usr/sbin"

# 10. 配置 NetworkManager
cp configs/*.nmconnection "${CHROOT}/etc/NetworkManager/system-connections"
chmod 0600 "${CHROOT}/etc/NetworkManager/system-connections"/*
sed -i '/\[main\]/a dns=dnsmasq' "${CHROOT}/etc/NetworkManager/NetworkManager.conf"

# 11. 配置 usb0 自动连接规则
cat << EOF > "${CHROOT}/etc/udev/rules.d/99-nm-usb0.rules"
SUBSYSTEM=="net", ACTION=="add|change|move", ENV{DEVTYPE}=="gadget", ENV{NM_UNMANAGED}="0"
EOF

# 12. 安装内核与 Extlinux 引导配置
wget -O - http://mirror.postmarketos.org/postmarketos/v26.06/aarch64/linux-postmarketos-qcom-msm8916-6.12.1-r5.apk \
    | tar xkzf - -C "${CHROOT}" --exclude=.PKGINFO --exclude=.SIGN* 2>/dev/null

mkdir -p "${CHROOT}/boot/extlinux"
cp configs/extlinux.conf "${CHROOT}/boot/extlinux"

# 复制设备树 DTB 文件
cp dtbs/* "${CHROOT}/boot/dtbs/qcom"

# 创建固件存放目录
mkdir -p "${CHROOT}/lib/firmware/msm-firmware-loader"

# 更新 fstab
printf "PARTUUID=80780b1d-0fe1-27d3-23e4-9244e62f8c46\t/boot\text2\tdefaults\t0 2\n" > "${CHROOT}/etc/fstab"

# 打包前清理静态 QEMU 文件（如果存在）
rm -f "${CHROOT}/usr/bin/qemu-aarch64-static"

# 13. 打包 rootfs
tar cpzf rootfs.tgz -C rootfs .