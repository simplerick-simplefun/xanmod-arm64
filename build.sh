#!/bin/bash
set -e

undefine() {
    for _config_name in "$@"; do
        scripts/config -k --undefine "${_config_name}"
    done
}

enable() {
    for _config_name in "$@"; do
        scripts/config -k --enable "${_config_name}"
    done
}

disable() {
    for _config_name in "$@"; do
        scripts/config -k --disable "${_config_name}"
    done
}

module() {
    for _config_name in "$@"; do
        scripts/config -k --module "${_config_name}"
    done
}

for i in "$@"; do
    case ${i,,} in
    --version=*)
        XANMODVER="${i#*=}"
        shift
        ;;
    --version)
        echo "Please use '--${i#--}=' to assign value to option"
        exit 1
        ;;
    -*)
        echo "Unknown option $i"
        exit 1
        ;;
    *) ;;
    esac
done

if [ -z "${XANMODVER}" ]; then
    echo "XANMODVER is not set"
    exit 1
fi

echo "xanmod version: ${XANMODVER}"

apt update &&
    apt install -y wget make clang llvm lld \
        flex bison libncurses-dev perl libssl-dev:arm64 libelf-dev:arm64 \
        libssl-dev:native libelf-dev:native build-essential lsb-release \
        bc debhelper debhelper-compat rsync kmod cpio \
        gcc-aarch64-linux-gnu 

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

# debug
disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
disable DEBUG_INFO
enable DEBUG_INFO_NONE
disable "SLUB_DEBUG" "PM_DEBUG" "PM_ADVANCED_DEBUG" "PM_SLEEP_DEBUG" "ACPI_DEBUG" "SCHED_DEBUG" "LATENCYTOP" "DEBUG_PREEMPT"

# ftrace
disable "FUNCTION_TRACER" "FUNCTION_GRAPH_TRACER"

# tickless
disable "NO_HZ_FULL_NODEF" "HZ_PERIODIC" "NO_HZ_FULL" "TICK_CPU_ACCOUNTING" "CONTEXT_TRACKING_FORCE"
enable "NO_HZ_IDLE" "NO_HZ" "NO_HZ_COMMON" "CONTEXT_TRACKING" "VIRT_CPU_ACCOUNTING" "VIRT_CPU_ACCOUNTING_GEN"

# debian/ubuntu don't properly support zstd module compression
disable MODULE_COMPRESS_NONE
disable MODULE_COMPRESS_ZSTD
disable MODULE_COMPRESS_GZIP
enable MODULE_COMPRESS_XZ

# cpu gov performance
disable "CPU_FREQ_DEFAULT_GOV_SCHEDUTIL"
enable "CPU_FREQ_DEFAULT_GOV_PERFORMANCE" "CPU_FREQ_DEFAULT_GOV_PERFORMANCE_NODEF"

# disable sig
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ''
scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ''

# then no need dwarves
disable DEBUG_INFO_BTF

# LTO
disable LTO_CLANG_FULL
disable LTO_CLANG_THIN
enable LTO_NONE

# MODULE SIG SHA1
scripts/config --set-str CONFIG_MODULE_SIG_HASH sha1
enable MODULE_SIG_SHA1
disable MODULE_SIG_SHA224
disable MODULE_SIG_SHA256
disable MODULE_SIG_SHA384
disable MODULE_SIG_SHA512

# bbr
enable "TCP_CONG_ADVANCED"
_tcp_cong_alg_list=("yeah" "bbr" "cubic" "reno")
for _alg in "${_tcp_cong_alg_list[@]}"; do
    _alg_upper=$(echo "$_alg" | tr '[a-z]' '[A-Z]')
    enable "TCP_CONG_${_alg_upper}"
    disable "DEFAULT_${_alg_upper}"
done
enable "DEFAULT_BBR"
scripts/config --set-str "DEFAULT_TCP_CONG" "bbr"

disable "VIRTIO_BALLOON"


MAKE="make -j$(nproc) ARCH=arm64 LLVM=1 LLVM_IAS=1"

$MAKE olddefconfig

$MAKE
echo "build done"

$MAKE modules
echo "build modules done"

echo "release deb"
$MAKE bindeb-pkg

mkdir -p debs

rm -rf debs/*

mv ../linux-headers-${XANMODVER}*.deb debs
mv ../linux-image-${XANMODVER}*.deb debs
mv ../linux-libc-dev_${XANMODVER}*.deb debs
mv ../linux-upstream_${XANMODVER}*.buildinfo debs
