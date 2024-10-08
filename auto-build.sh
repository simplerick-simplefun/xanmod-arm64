#!/bin/bash
set -e

XANMOD_LATEST_TAG=$1
XANMODVER="${XANMOD_LATEST_TAG%%-*}"

echo "xanmod version: ${XANMODVER}"

apt update &&
    apt install -y wget make clang llvm lld \
        flex bison libncurses-dev perl libssl-dev:native \
        libelf-dev:native build-essential lsb-release \
        bc debhelper rsync kmod cpio

rm -rf linux-${XANMOD_LATEST_TAG}.tar.gz
wget https://gitlab.com/xanmod/linux/-/archive/${XANMOD_LATEST_TAG}/linux-${XANMOD_LATEST_TAG}.tar.gz
mkdir -p linux-${XANMOD_LATEST_TAG}-kernel
rm -rf linux-${XANMOD_LATEST_TAG}-kernel/*
tar -zxf "linux-${XANMOD_LATEST_TAG}.tar.gz" \
    -C linux-${XANMOD_LATEST_TAG}-kernel \
    --strip-components=1
cd linux-${XANMOD_LATEST_TAG}-kernel

cp ../configs/config-6.6.13+bpo-arm64 .config

scripts/config --set-str CONFIG_LOCALVERSION '-arm64'

scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
scripts/config --set-val CONFIG_DEBUG_INFO_NONE y

# disable sig
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ''
scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ''

scripts/config --disable CONFIG_DEBUG_INFO_BTF # then no need dwarves
scripts/config --disable CONFIG_DEBUG_INFO_DWARF5

# LTO
scripts/config --enable CONFIG_LTO_CLANG_THIN

# MODULE SIG SHA1
scripts/config --set-val CONFIG_MODULE_SIG_SHA1 y
scripts/config --set-str CONFIG_MODULE_SIG_HASH sha1
scripts/config --disable CONFIG_MODULE_SIG_SHA224
scripts/config --disable CONFIG_MODULE_SIG_SHA256
scripts/config --disable CONFIG_MODULE_SIG_SHA384
scripts/config --disable CONFIG_MODULE_SIG_SHA512

MAKE="make -j$(nproc) ARCH=arm64 LLVM=1 LLVM_IAS=1"

$MAKE olddefconfig

$MAKE
echo "build done"

echo "release deb"
$MAKE bindeb-pkg

mkdir -p debs

rm -rf debs/*

mv ../linux-headers-${XANMODVER}*.deb debs
mv ../linux-image-${XANMODVER}*.deb debs
mv ../linux-libc-dev_${XANMODVER}*.deb debs
mv ../linux-upstream_${XANMODVER}*.buildinfo debs
