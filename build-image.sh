#!/bin/bash
# Environment
export WORKDIR=$(pwd)
export KERNEL_REPO=kernel

clean(){
    cd ${WORKDIR}
    echo "cleaning"
    rm -rf openEuler_raspi.img openEuler_raspi.img.gz rootfs/ boot/ root/ rootfs.tar
}
