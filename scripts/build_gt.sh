#!/bin/sh -e

CHROOT=${CHROOT:-$(pwd)/rootfs}
SRCDIR=$(pwd)/src
ARCH=$(uname -m)

# 1. 架构自适应判断
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "Configuring native ARM64 build for gadget-tool..."
    CHROOT_PREFIX=""
    CC="gcc"
    CXX="g++"
    HOST_FLAG=""
else
    echo "Configuring cross-compile build for gadget-tool (x86_64)..."
    CHROOT_PREFIX="qemu-aarch64-static"
    CC="aarch64-linux-gnu-gcc"
    CXX="aarch64-linux-gnu-g++"
    HOST_FLAG="--host aarch64-linux-gnu"
fi

# 2. 在 rootfs 内安装依赖
chroot "${CHROOT}" ${CHROOT_PREFIX} /bin/sh \
    -c "apt-get update && apt-get install -y libconfig-dev"

# 3. 编译并安装 libusbgx 到 dist 目录
(
    cd "${SRCDIR}/libusbgx"
    autoreconf -i
)

mkdir -p build
(
    cd build
    PKG_CONFIG_PATH="${CHROOT}/usr/lib/aarch64-linux-gnu/pkgconfig:${CHROOT}/usr/lib/pkgconfig" \
        "${SRCDIR}/libusbgx/configure" \
            ${HOST_FLAG} \
            --prefix=/usr \
            --with-sysroot="${CHROOT}"
)

# 编译 libusbgx 并临时导出到 dist
make -C build DESTDIR="$(pwd)/dist" CFLAGS="--sysroot=${CHROOT}" install

# 4. 编译 gt (gadget-tool)
rm -rf build/*

PKG_CONFIG_PATH="$(pwd)/dist/usr/lib/pkgconfig:${CHROOT}/usr/lib/aarch64-linux-gnu/pkgconfig:${CHROOT}/usr/lib/pkgconfig" \
    cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_CXX_COMPILER="${CXX}" \
        -DCMAKE_C_COMPILER="${CC}" \
        -DCMAKE_C_FLAGS="-I$(pwd)/dist/usr/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L$(pwd)/dist/usr/lib" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_SYSROOT="${CHROOT}" \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -S "${SRCDIR}/gt/source" \
        -B build

make -C build DESTDIR="$(pwd)/dist" install

# 5. 清理多余开发文件，仅保留运行时组件
rm -rf dist/usr/share dist/usr/lib/cmake dist/usr/lib/pkgconfig \
    dist/usr/lib/*a dist/usr/bin/ga* dist/usr/bin/s* dist/usr/include

# 复制模板配置
mkdir -p dist/etc
cp -a configs/templates dist/etc/gt

echo "gadget-tool and libusbgx built successfully."