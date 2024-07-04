#!/bin/bash
set -e

LASTBUILDVER=$1
XANMODVER=$2
XANMODVER="${XANMODVER%%-*}"

if [[ "$LASTBUILDVER" == "$XANMODVER" ]]; then
    echo "Current xanmod release version $$XANMODVER is same as version of last build. No need to build. Exit."
    exit 0
fi

echo "xanmod version: ${XANMODVER}"

apt update &&
    apt install -y wget make clang llvm lld \
        flex bison libncurses-dev perl libssl-dev:native \
        libelf-dev:native build-essential lsb-release \
        bc debhelper rsync kmod cpio

rm -rf linux-${XANMODVER}-xanmod1.tar.gz
wget https://gitlab.com/xanmod/linux/-/archive/${XANMODVER}-xanmod1/linux-${XANMODVER}-xanmod1.tar.gz
mkdir -p linux-${XANMODVER}-kernel
rm -rf linux-${XANMODVER}-kernel/*
tar -zxf "linux-${XANMODVER}-xanmod1.tar.gz" \
    -C linux-${XANMODVER}-kernel \
    --strip-components=1
cd linux-${XANMODVER}-kernel

cp ../configs/config-6.6.13+bpo-arm64 .config

scripts/config --set-str CONFIG_LOCALVERSION '-arm64'

scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
scripts/config --set-val CONFIG_DEBUG_INFO_NONE y

# disable sig
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ''
scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ''

scripts/config --disable CONFIG_DEBUG_INFO_BTF # then no need dwarves

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
