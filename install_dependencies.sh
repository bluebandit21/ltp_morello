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
cp -r bin/ ${script_dir}/toolchain/bin/
cp -r include/ ${script_dir}/toolchain/include/
cp -r lib/ ${script_dir}/toolchain/lib/
cp -r libexec/ ${script_dir}/toolchain/libexec/
cp -r share/ ${script_dir}/toolchain/share/


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

cd cd ${script_dir}


## Kernel Headers











cd ${curr_dir}
