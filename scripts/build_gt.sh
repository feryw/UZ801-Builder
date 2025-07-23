#!/bin/sh -e

CHROOT=${CHROOT=$(pwd)/rootfs}
SRCDIR=$(pwd)/src

# install gt dependencies
chroot ${CHROOT} qemu-armhf-static /bin/sh \
    -c " apt update; apt install libconfig-dev -y"

# build and install gt
(
cd src/libusbgx/
autoreconf -i
)

mkdir -p build
(
cd build
PKG_CONFIG_PATH=${CHROOT}/usr/lib/arm-linux-gnueabihf/pkgconfig \
    ${SRCDIR}/libusbgx/configure \
        --host arm-linux-gnueabihf \
        --prefix=/usr \
        --with-sysroot=${CHROOT}
)
make -C build DESTDIR=$(pwd)/dist CFLAGS="--sysroot=${CHROOT}" install
make -C build CFLAGS="--sysroot=${CHROOT}" install

rm -rf build/*
PKG_CONFIG_PATH=${CHROOT}/usr/lib/pkgconfig:${CHROOT}/usr/lib/arm-linux-gnueabihf/pkgconfig \
    cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_CXX_COMPILER=arm-linux-gnueabihf-g++ \
        -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc \
        -DCMAKE_C_FLAGS=-I$(pwd)/dist/usr/include \
        -DCMAKE_C_FLAGS=-L$(pwd)/dist/usr/lib \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_SYSROOT=${CHROOT} \
        -DCMAKE_SYSTEM_PROCESSOR=arm \
        -S ${SRCDIR}/gt/source \
        -B build

make -C build DESTDIR=$(pwd)/dist install

rm -rf dist/usr/share dist/usr/lib/cmake dist/usr/lib/pkgconfig \
    dist/usr/lib/*a dist/usr/bin/ga* dist/usr/bin/s* dist/usr/include

cp -a configs/templates dist/etc/gt
