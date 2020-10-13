# 项目简介



## 基本信息



### 目录



#### Submodule

- firmware
    - https://github.com/raspberrypi/firmware.git

- firmware-nonfree
    - https://github.com/RPi-Distro/firmware-nonfree.git
- bluez-firmware
    - https://github.com/RPi-Distro/bluez-firmware.git

- pi-bluetooth
    - url = https://github.com/RPi-Distro/pi-bluetooth.git

- raspberrypi-sys-mods
    - https://github.com/RPi-Distro/raspberrypi-sys-mods.git

- kernel
    - https://github.com/earlytobed/kernel.git

- raspberrypi-kernel
    - https://github.com/earlytobed/raspberrypi-kernel.git

其中，`kernel` 仓库是我编译的树莓派内核，`raspberrypi-kernel` 仓库是内核源码



#### raspi-configs

- `rootfs-sample`
    - 构建镜像需要的一些配置文件
- `yum.repos.d`
    - 构建镜像时需要的 repo 配置



#### 脚本文件

- `build-image.sh`
    - 用于构建精简树莓派镜像

- `build-kernel.sh`
    - 用于编译收集树莓派精简内核



### 镜像构建脚本说明

克隆仓库

```bash
git clone https://isrc.iscas.ac.cn/gitlab/summer2020/students/proj-2021101.git openeuler-raspberrypi-ws
```

执行 `build-image.sh`

```
cd openeuler-raspberrypi-ws
./build-image.sh
```

手动清理构建过程中的产物

```
./build-image.sh clean
```



### 编译精简内核脚本说明

编辑 `shrink_defconfig`

```bash
#!/bin/bash
cd raspberrypi-kernel/
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export target=shrink_defconfig

make ${target}
make menuconfig
\cp .config arch/${ARCH}/configs/${target}
```

编译 `shrink_defconfig` 并收集编译产物至 `kernel` 目录，记录大小作为 `git commit message`

```
./build-kernel.sh
```

