#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: vcyzteen

# run all
run() {
   download_resources
   build_binutils
   build_gcc
   notif
}

# telegram api
tg_post_msg() {
	curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$ID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

tg_post_build() {
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "https://api.telegram.org/bot$TOKEN/sendDocument" \
	-F chat_id="$ID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2 | *MD5 Checksum : *\`$MD5CHECK\`"
}

# TODO: Add more dynamic option handling
while getopts a: flag; do
  case "${flag}" in
    a) arch=${OPTARG} ;;
  esac
done

# TODO: Better target handling
case "${arch}" in
  "arm") TARGET="arm-eabi" ;;
  "arm64") TARGET="aarch64-elf" ;;
  "arm64gnu") TARGET="aarch64-linux-gnu" ;;
  "x86") TARGET="x86_64-elf" ;;
esac

export WORK_DIR="$PWD"
export PREFIX="$WORK_DIR/../gcc-${arch}"
export PATH="$PREFIX/bin:/usr/bin/core_perl:$PATH"

tg_post_msg "|| Building Toolchain for ${arch} with ${TARGET} as target ||"

download_resources() {
  git clone --depth=1 git://sourceware.org/git/binutils-gdb.git -b master binutils --depth=1
  git clone --depth=1 git://gcc.gnu.org/git/gcc.git -b releases/gcc-4.9 gcc --depth=1
  cd ${WORK_DIR}
}

build_binutils() {
  cd ${WORK_DIR}
  echo "Building Binutils"
  mkdir build-binutils
  cd build-binutils
  ../binutils/configure --target=$TARGET \
    CFLAGS="-flto -flto-compression-level=10 -O3 -pipe -ffunction-sections -fdata-sections" \
    CXXFLAGS="-flto -flto-compression-level=10 -O3 -pipe -ffunction-sections -fdata-sections" \
    --prefix="$PREFIX" \
    --with-sysroot \
    --disable-nls \
    --disable-docs \
    --disable-werror \
    --disable-gdb \
    --enable-gold \
    --with-pkgversion="$NAMEPKG"
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
  echo "Bleeding Edge" > gcc/DEV-PHASE
  cd ../
  mkdir build-gcc
  cd build-gcc
  ../gcc/configure --target=$TARGET \
    CFLAGS="-flto -flto-compression-level=10 -O3 -pipe -ffunction-sections -fdata-sections" \
    CXXFLAGS="-flto -flto-compression-level=10 -O3 -pipe -ffunction-sections -fdata-sections" \
    --prefix="$PREFIX" \
    --disable-decimal-float \
    --disable-gcov \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libstdcxx-pch \
    --disable-nls \
    --disable-shared \
    --disable-docs \
    --enable-default-ssp \
    --enable-languages=c,c++ \
    --enable-threads=posix \
    --with-pkgversion="$NAMEPKG" \
    --with-newlib \
    --with-gnu-as \
    --with-gnu-ld \
    --with-linker-hash-style=gnu \
    --with-sysroot \
    --with-headers="/usr/include"

  make all-gcc -j$(($(nproc --all) + 2))
  make all-target-libgcc -j$(($(nproc --all) + 2))
  make install-gcc -j$(($(nproc --all) + 2))
  make install-target-libgcc -j$(($(nproc --all) + 2))
  echo "Built GCC!"
}

notif() {
  tg_post_build "binutils.log" "gcc.log" "*here for the log*" "*gcc has been uploaded on $(/bin/date)*"
}

run
