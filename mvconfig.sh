#!/bin/bash
cd raspberrypi-kernel/
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export target=shrink_defconfig

\cp .config arch/${ARCH}/configs/${target}
