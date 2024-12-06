#!/bin/bash

set -e

export curr_dir=`pwd`
export script_dir=$(dirname $(readlink -f "${0}"))
cd ${script_dir}



export PATH="${script_dir}/toolchain/bin":"${PATH}"
export LD_LIBRARY_PATH="${script_dir}/toolchain/lib":"${LD_LIBRARY_PATH}"

export TRIPLE="aarch64-linux-gnu"
export MORELLO_SUPPORT="--disable-morello"




## Kernel Headers
cd "${script_dir}/../morello_workspace/linux/"
make headers_install HOSTCC=clang CC=clang ARCH=arm64 INSTALL_HDR_PATH="${script_dir}/morello_toolchain"



# Morello Linux LTP!
cd "${script_dir}"

cd morello-linux-ltp-morello-release-1.8.0

export KHDR_DIR="${script_dir}/morello_toolchain"
export MUSL="${script_dir}/morello_toolchain"
export LTP_BUILD="${script_dir}/ltp_build"
export LTP_INSTALL="${script_dir}/ltp_install"

rm -rf ${LTP_BUILD}
rm -rf ${LTP_INSTALL}

$(
    CFLAGS="--target=${TRIPLE} ${TARGET_FEATURE} --sysroot=${MUSL} \
        -isystem ${KHDR_DIR}/usr/include -g -Wall"
    LDFLAGS="--target=${TRIPLE} -rtlib=compiler-rt --sysroot=${MUSL} \
         -fuse-ld=lld -static -L${LTP_BUILD}/lib"
        export CC=clang
    export HOST_CFLAGS="-O2 -Wall"
    export HOST_LDFLAGS="-Wall"
    export CONFIGURE_OPT_EXTRA="--prefix=/ --host=aarch64-linux-gnu --disable-metadata --without-numa"

    MAKE_OPTS="TST_NEWER_64_SYSCALL=no TST_COMPAT_16_SYSCALL=no" \
    TARGETS="pan tools/apicmds testcases/kernel/syscalls" BUILD_DIR="$LTP_BUILD" \
    CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
    ./build.sh -t cross -o out -ip "${LTP_INSTALL}"
)


cd ${curr_dir}
