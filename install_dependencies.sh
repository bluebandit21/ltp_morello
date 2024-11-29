#!/bin/bash

set -e

export curr_dir=`pwd`
export script_dir=$(dirname $(readlink -f "${0}"))
cd ${script_dir}



rm -rf toolchain/
mkdir -p toolchain
mkdir -p toolchain/bin
mkdir -p toolchain/include
mkdir -p toolchain/lib
mkdir -p toolchain/libexec
mkdir -p toolchain/share


rm -rf morello_toolchain/
mkdir -p morello_toolchain




## Acquire llvm

rm -rf dependency_tmp
mkdir -p dependency_tmp
cd dependency_tmp

wget "https://git.morello-project.org/morello/llvm-project-releases/-/archive/morello/linux-release-1.8/llvm-project-releases-morello-linux-release-1.8.tar.gz"
tar -xzf "llvm-project-releases-morello-linux-release-1.8.tar.gz"

cd llvm-project-releases-morello-linux-release-1.8
cp -r bin/ ${script_dir}/toolchain/
cp -r include/ ${script_dir}/toolchain/
cp -r lib/ ${script_dir}/toolchain/
cp -r libexec/ ${script_dir}/toolchain/
cp -r share/ ${script_dir}/toolchain/


export PATH="${script_dir}/toolchain/bin":"${PATH}"
export LD_LIBRARY_PATH="${script_dir}/toolchain/lib":"${LD_LIBRARY_PATH}"

## MUSL
cd ${script_dir}/dependency_tmp/

wget https://git.morello-project.org/morello/musl-libc/-/archive/morello-release-1.8.0/musl-libc-morello-release-1.8.0.tar.gz
tar -xzf "musl-libc-morello-release-1.8.0.tar.gz"
cd "musl-libc-morello-release-1.8.0"

export TRIPLE="aarch64-linux-gnu"
export MORELLO_SUPPORT="--disable-morello"


CC="clang" ./configure --disable-shared \
${MORELLO_SUPPORT} \
--disable-libshim \
--target=${TRIPLE} \
--prefix="${script_dir}/morello_toolchain"

make
make install

cd ${script_dir}


## Kernel Headers
cd "${script_dir}/../morello_workspace/linux/"
make headers_install HOSTCC=clang CC=clang ARCH=arm64 INSTALL_HDR_PATH="${script_dir}/morello_toolchain"



# Morello Linux LTP!
cd "${script_dir}"
wget "https://git.morello-project.org/morello/morello-linux-ltp/-/archive/morello-release-1.8.0/morello-linux-ltp-morello-release-1.8.0.tar"
tar -xf "morello-linux-ltp-morello-release-1.8.0.tar"
rm "morello-linux-ltp-morello-release-1.8.0.tar"

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
