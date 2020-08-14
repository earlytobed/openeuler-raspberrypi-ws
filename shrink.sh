#!/bin/bash
cd raspberrypi-kernel/
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export target=shrink_defconfig

make ${target}
make menuconfig

read -p "\cp .config arch/${ARCH}/configs/${target} ?" yesorno
if [ $yesorno == "yes" ]; then
    \cp .config arch/${ARCH}/configs/${target}
fi
