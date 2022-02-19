#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: vcyzteen

# run all
run() {
   tg_post_msg "<code>cloning gcc & binutils</code>"
   download_resources
   tg_post_msg "<code>cloning has been succesfull</code>"
   tg_post_msg "<code>building binutils...</code>"
   build_binutils
   tg_post_build "binutils.log" "*build binutils has been succesfull...*"
   tg_post_msg "<code>building gcc.../code>"
   build_gcc
   tg_post_build "gcc.log" "*build gcc has been succesfull...*"
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
  "arm") TARGET="arm-linux-gnueabi" ;;
  "arm64") TARGET="aarch64-linux-gnu" ;;
  "x86") TARGET="x86_64-linux-gnu" ;;
esac

export WORK_DIR="$PWD"
export PREFIX="$PWD/../gcc-${arch}"
export PATH="$PREFIX/bin:$PATH"

tg_post_msg "|| Building Toolchain for ${arch} with ${TARGET} as target ||"

download_resources() {
  git clone --depth=1 git://sourceware.org/git/binutils-gdb.git -b master binutils --depth=1
  git clone --depth=1 git://gcc.gnu.org/git/gcc.git -b master gcc --depth=1
  cd ${WORK_DIR}
}

build_binutils() {
  cd ${WORK_DIR}
  mkdir build-binutils
  cd build-binutils
  ../binutils/configure --target=$TARGET \
    --prefix="$PREFIX" \
    --with-sysroot \
    --disable-nls \
    --disable-docs \
    --disable-werror \
    --disable-gdb \
    --disable-gold \
    --with-newlib \
    --with-gnu-as \
    --with-gnu-ld \
    --with-pkgversion="$NAMEPKG" \
    --with-linker-hash-style=gnu

  make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" CXXFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" -j$(($(nproc --all) + 2))
  make install -j$(($(nproc --all) + 2)) 2>&1 | tee binutils.log
  cd ../
}

build_gcc() {
  cd ${WORK_DIR}
  cd gcc
  ./contrib/download_prerequisites
  cd ../
  mkdir build-gcc
  cd build-gcc
  ../gcc/configure --target=$TARGET \
    --prefix="$PREFIX" \
    --disable-decimal-float \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libstdcxx-pch \
    --disable-nls \
    --disable-docs \
    --disable-werror \
    --with-pkgversion="$NAMEPKG" \
    --with-newlib \
    --with-gnu-as \
    --with-gnu-ld \
    --enable-shared \
    --enable-threads=posix \
    --enable-__cxa_atexit \
    --enable-clocale=gnu \
    --enable-languages=all \
    --disable-multilib \
    --enable-linker-build-id \
    --with-sysroot

  make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" CXXFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" all-gcc -j$(($(nproc --all) + 2))
  make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" CXXFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" install-gcc -j$(($(nproc --all) + 2)) 2>&1 | tee binutils.log
}

run
