#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: xealea

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
  "arm64") TARGET="aarch64-linux-gnu" ;;
    "arm") TARGET="arm-linux-gnueabi" ;;
esac

export WORK_DIR="$PWD"
export PREFIX="$WORK_DIR/../gcc-${arch}"
export PATH="$PREFIX/bin:/usr/bin/core_perl:$PATH"

tg_post_msg "|| Building Toolchain for ${arch} with ${TARGET} as target ||"

download_resources() {
  git clone --depth=1 git://sourceware.org/git/binutils-gdb.git -b binutils-2_39-branch binutils --depth=1
  git clone --depth=1 git://gcc.gnu.org/git/gcc.git -b releases/gcc-12 --depth=1
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
        --with-lib-path="$PREFIX"/lib \
        --enable-deterministic-archives \
        --enable-gold \
        --enable-ld=default \
        --enable-lto \
        --enable-plugins \
        --enable-relro \
        --enable-targets=$TARGET-pep \
        --enable-threads \
        --disable-gdb \
        --disable-werror \
        --with-pic \
        --with-system-zlib \
        --with-pkgversion='xea-xo1-binutils'

  make -j$(($(nproc --all) + 2))
  make install -j$(($(nproc --all) + 2))
  cd ../
  # Remove unwanted files
  rm -f "$PREFIX"/share/man/man1/{dlltool,nlmconv,windres,windmc}*
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
    CFLAGS="-flto -flto-compression-level=10 -O3 -pipe -ffunction-sections -fdata-sections" \
    CXXFLAGS="-flto -flto-compression-level=10 -O3 -pipe -ffunction-sections -fdata-sections" \
        --prefix="$PREFIX" \
        --with-pkgversion='xea-xo1-gcc' \
        --libdir="$PREFIX"/lib \
        --libexecdir="$PREFIX"/lib \
        --with-lib-path="$PREFIX"/lib \
        --enable-languages=c,c++,lto \
        --with-gcc-major-version-only \
        --with-linker-hash-style=both \
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
        --enable-lto \
        --enable-multilib \
        --enable-plugin \
        --enable-shared \
        --enable-threads=posix \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-werror

  make all-gcc -j$(($(nproc --all) + 2))
  make all-target-libgcc -j$(($(nproc --all) + 2))
  make install-gcc -j$(($(nproc --all) + 2))
  make install-target-libgcc -j$(($(nproc --all) + 2))
  echo "Built GCC!"

  # create lto plugin link
  mkdir -p "$PREFIX"/lib/bfd-plugins
  ln -sf "$PREFIX"/libexec/gcc/$TARGET/12.2.0/liblto_plugin.so "$PREFIX"/lib/bfd-plugins/liblto_plugin.so
}

notif() {
  tg_post_build "binutils.log" "gcc.log" "*here for the log*" "*gcc has been uploaded on $(/bin/date)*"
}

run
