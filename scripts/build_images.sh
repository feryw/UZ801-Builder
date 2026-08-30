#!/bin/sh -e

CHROOT=${CHROOT:-$(pwd)/rootfs}

# 1. 注册异常中断安全卸载与清理
cleanup() {
    umount -l mnt 2>/dev/null || true
    rm -rf mnt
}
trap cleanup EXIT INT TERM

# 2. 准备输出目录与临时挂载点
rm -f rootfs.raw boot.raw
mkdir -p files mnt

# 3. 创建并打包 boot 分区镜像 (64MB ext2)
echo "Creating boot image..."
truncate -s 67108864 boot.raw
mkfs.ext2 -F -L boot boot.raw
mount -o loop boot.raw mnt
tar xf rootfs.tgz -C mnt ./boot --exclude='./boot/linux.efi' --strip-components=2
umount mnt

# 4. 创建并打包 rootfs 分区镜像 (1.5GB ext4)
echo "Creating rootfs image..."
truncate -s 1610612736 rootfs.raw
mkfs.ext4 -F -L rootfs rootfs.raw
mount -o loop rootfs.raw mnt
tar xpf rootfs.tgz -C mnt --exclude='./boot/*' --exclude='./root/*' --exclude='./dev/*'

# 安装 gadget-tool 与 USB 配置文件
if [ -d "dist" ]; then
    cp -a dist/* mnt/
fi

umount mnt

# 5. 转换为 Android Fastboot 兼容的 Sparse 镜像
echo "Converting raw images to Android sparse format..."
img2simg rootfs.raw files/rootfs.bin
img2simg boot.raw files/boot.bin

# 6. 清理 raw 中间临时大文件
rm -f rootfs.raw boot.raw

echo "Images built successfully: files/boot.bin, files/rootfs.bin"