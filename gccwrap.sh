#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: xealea

# TODO: Add more dynamic option handling
while getopts a: flag; do
  case "${flag}" in
    a) arch=${OPTARG} ;;
  esac
done

# TODO: Better target handling
case "${arch}" in
  "arm") TARGET="arm-linux-gnueabi" ;;
  "arm64") TARGET="aarch64-linux-gnu" ;;
esac

export WORK_DIR="$PWD"
export PREFIX="$WORK_DIR/../gcc-${arch}"
export PATH="$PREFIX/bin:/usr/bin/core_perl:$PATH"

echo "||                                                                    ||"
echo "|| Building Bare Metal Toolchain for ${arch} with ${TARGET} as target ||"
echo "||                                                                    ||"

download_resources() {
  echo "Downloading Pre-requisites"
  echo "Cloning binutils"
  git clone git://sourceware.org/git/binutils-gdb.git -b binutils-2_39-branch binutils --depth=1
  echo "Cloned binutils!"
  echo "Cloning GCC"
  git clone git://gcc.gnu.org/git/gcc.git -b releases/gcc-12 gcc --depth=1
  cd ${WORK_DIR}
  echo "Downloaded prerequisites!"
}

build_binutils() {
  cd ${WORK_DIR}
  echo "Building Binutils"
  mkdir build-binutils
  cd build-binutils
  ../binutils/configure --target=$TARGET \
    CFLAGS="-O2 -pipe -ffunction-sections -fdata-sections" \
    CXXFLAGS="-O2 -pipe -ffunction-sections -fdata-sections" \
    --disable-docs \
    --disable-gdb \
    --disable-nls \
    --disable-werror \
    --enable-gold \
    --with-pic \
    --enable-plugins \
    --enable-relro \
    --enable-threads \
    --with-system-zlib \
    --prefix="$PREFIX" \
    --with-pkgversion="Xo4 Binutils" \
    --with-sysroot
  make -j$(($(nproc --all) + 2))
  make install -j$(($(nproc --all) + 2))
  cd ../
  echo "Built Binutils, proceeding to next step...."
}

build_gcc() {
  cd ${WORK_DIR}
  echo "Building GCC"
  cd gcc
  ./contrib/download_prerequisites
  echo "Baremetal" > gcc/DEV-PHASE
  cd ../
  mkdir build-gcc
  cd build-gcc
  ../gcc/configure --target=$TARGET \
    CFLAGS="-O2 -pipe -ffunction-sections -fdata-sections" \
    CXXFLAGS="-O2 -pipe -ffunction-sections -fdata-sections" \
    --disable-decimal-float \
    --disable-docs \
    --disable-gcov \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libstdcxx-pch \
    --disable-nls \
    --enable-default-ssp \
    --enable-languages=c,c++ \
    --enable-threads=posix \
    --prefix="$PREFIX" \
    --with-gnu-as \
    --with-gnu-ld \
    --with-headers="/usr/include" \
    --with-linker-hash-style=gnu \
    --with-newlib \
    --with-gcc-major-version-only \
    --with-system-zlib \
    --enable-__cxa_atexit \
    --enable-cet=auto \
    --enable-checking=release \
    --enable-clocale=gnu \
    --enable-default-pie \
    --enable-default-ssp \
    --enable-gnu-indirect-function \
    --enable-gnu-unique-object \
    --enable-linker-build-id \
    --enable-multilib \
    --enable-plugin \
    --enable-shared \
    --disable-libssp \
    --with-pkgversion="Xo4 GCC" \
    --with-sysroot

  make all-gcc -j$(($(nproc --all) + 2))
  make all-target-libgcc -j$(($(nproc --all) + 2))
  make install-gcc -j$(($(nproc --all) + 2))
  make install-target-libgcc -j$(($(nproc --all) + 2))
  echo "Built GCC!"
}

download_resources
build_binutils
build_gcc
