#!/bin/bash
# Env
export WORKDIR=$(pwd)
export SOURCE=raspberrypi-kernel
export OUTPUT=temp
export KERNEL_REPO=kernel
export ARCH=arm64
export TARGET=shrink_defconfig

# Prepare
## mkdir
cd ${WORKDIR}
mkdir ${OUTPUT}
mkdir ${KERNEL_REPO}

## clean
cd ${WORKDIR}/${SOURCE}
make mrproper
cd ${WORKDIR}/${KERNEL_REPO}
git rm -r .
cd ${WORKDIR}/${OUTPUT}
rm -rf *

# Compile
cd ${WORKDIR}/${SOURCE}
## kernel
make ${TARGET}
make -j96

## kernel modules
make INSTALL_MOD_PATH=${WORKDIR}/${OUTPUT}/ modules_install

# Collect
## kernel
cp ${WORKDIR}/${SOURCE}/arch/${ARCH}/boot/Image ${WORKDIR}/${OUTPUT}/

## device tree binary
cp ${WORKDIR}/${SOURCE}/arch/${ARCH}/boot/dts/broadcom/*.dtb ${WORKDIR}/${OUTPUT}/
mkdir ${WORKDIR}/${OUTPUT}/overlays
cp ${WORKDIR}/${SOURCE}/arch/${ARCH}/boot/dts/overlays/*.dtb* ${WORKDIR}/${OUTPUT}/overlays/

# Finish
cd ${WORKDIR}
## size
SIZE=$(du -d 0 ${OUTPUT} | awk '{print $1}')
## target_defconfig
cp ${WORKDIR}/${SOURCE}/arch/${ARCH}/configs/${TARGET} ${WORKDIR}/${OUTPUT}
## mv
cp -rf ${WORKDIR}/${OUTPUT}/* ${WORKDIR}/${KERNEL_REPO}/

# Git
cd ${WORKDIR}/${KERNEL_REPO}
git add .
git commit -m "${SIZE}"
