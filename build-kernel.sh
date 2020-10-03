#!/bin/bash
# Environment
## make
export ARCH=arm64
export TARGET=shrink_defconfig
## dir
export WORKDIR=$(pwd)
export SOURCE=raspberrypi-kernel
export KERNEL_REPO=kernel
export TEMP_DIR=temp

set -e

# Prepare
## mkdir
cd ${WORKDIR}
if [ ! -d "${SOURCE}" ]; then
    echo "No raspberrypi-kernel. Wrong Path!"
    exit 1
fi
if [ ! -d "${KERNEL_REPO}" ]; then
    echo "No kernel-repo."
    mkdir ${KERNEL_REPO}
    cd ${WORKDIR}/${KERNEL_REPO}
    git init .
fi
mkdir ${TEMP_DIR}
## clean
cd ${WORKDIR}/${SOURCE} && make mrproper
cd ${WORKDIR}/${KERNEL_REPO} && git rm -r .
cd ${WORKDIR}/${TEMP_DIR} && rm -rf *

# Compile
cd ${WORKDIR}/${SOURCE}
## kernel
make ${TARGET} && make -j$($(nproc) || echo 4)

# Collect
## kernel
make INSTALL_MOD_PATH=${WORKDIR}/${TEMP_DIR}/ modules_install
cp ${WORKDIR}/${SOURCE}/arch/${ARCH}/boot/Image ${WORKDIR}/${TEMP_DIR}/
## device tree binary
cp ${WORKDIR}/${SOURCE}/arch/${ARCH}/boot/dts/broadcom/*.dtb ${WORKDIR}/${TEMP_DIR}/
mkdir ${WORKDIR}/${TEMP_DIR}/overlays
cp ${WORKDIR}/${SOURCE}/arch/${ARCH}/boot/dts/overlays/*.dtb* ${WORKDIR}/${TEMP_DIR}/overlays/

# Finish
cd ${WORKDIR}
## size
SIZE=$(du -d 0 ${TEMP_DIR} | awk '{print $1}')
## target_defconfig
cp ${WORKDIR}/${SOURCE}/arch/${ARCH}/configs/${TARGET} ${WORKDIR}/${TEMP_DIR}
## mv
cp -rf ${WORKDIR}/${TEMP_DIR}/* ${WORKDIR}/${KERNEL_REPO}/

# Git
cd ${WORKDIR}/${KERNEL_REPO}
git add .
git commit -m "${SIZE}"
