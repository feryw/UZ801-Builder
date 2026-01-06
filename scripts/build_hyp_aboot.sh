#!/bin/sh -eu

TYPEDEV="${DEV_TYPE:?DEV_TYPE not set}"

case "$TYPEDEV" in
  uz801)
    DESCR="yiming,uz801-v3"
    ;;
  uf896)
    DESCR="thwc,uf896"
    ;;
  ufi001c)
    DESCR="thwc,ufi001c"
    ;;
  *)
    echo "Unsupported device: $TYPEDEV" >&2
    exit 1
    ;;
esac
    
make -C src/qhypstub CROSS_COMPILE=aarch64-linux-gnu-

# patch to reduce mmc speed as some boards have intermittent failures when
# inititalizing the mmc (maybe due to using old/recycled flash chips)
echo 'DEFINES += USE_TARGET_HS200_CAPS=1' >> src/lk2nd/project/lk1st-msm8916.mk

make -C src/lk2nd \
  LK2ND_BUNDLE_DTB="msm8916-512mb-mtp.dtb" \
  LK2ND_COMPATIBLE="$DESCR" \
  TOOLCHAIN_PREFIX=arm-none-eabi- \
  lk1st-msm8916 -j$(nproc)

# test sign
mkdir -p files
src/qtestsign/qtestsign.py hyp src/qhypstub/qhypstub.elf \
    -o files/hyp.mbn
src/qtestsign/qtestsign.py aboot src/lk2nd/build-lk1st-msm8916/emmc_appsboot.mbn \
    -o files/aboot.mbn
