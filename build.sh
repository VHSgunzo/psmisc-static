#!/bin/bash

export MAKEFLAGS="-j$(nproc)"

# WITH_UPX=1

platform="$(uname -s)"
platform_arch="$(uname -m)"

if [ -x "$(which apt 2>/dev/null)" ]
    then
        apt update && apt install -y \
            build-essential clang pkg-config git autoconf libtool libcap-dev \
            libncurses-dev gettext autopoint upx
fi

if [ -d build ]
    then
        echo "= removing previous build directory"
        rm -rf build
fi

if [ -d release ]
    then
        echo "= removing previous release directory"
        rm -rf release
fi

# create build and release directory
mkdir build
mkdir release
pushd build

# download psmisc
git clone https://gitlab.com/psmisc/psmisc.git
psmisc_version="$(cd psmisc && git describe --long --tags|sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')"
mv psmisc "psmisc-${psmisc_version}"
echo "= downloading psmisc v${psmisc_version}"

if [ "$platform" == "Linux" ]
    then
        export CFLAGS="-static"
        export LDFLAGS='--static'
    else
        echo "= WARNING: your platform does not support static binaries."
        echo "= (This is mainly due to non-static libc availability.)"
fi

echo "= building psmisc"
pushd psmisc-${psmisc_version}
env CFLAGS="$CFLAGS -g -O2 -Os -ffunction-sections -fdata-sections" ./autogen.sh
env CFLAGS="$CFLAGS -g -O2 -Os -ffunction-sections -fdata-sections" ./configure \
    --disable-w --disable-shared LDFLAGS="$LDFLAGS -Wl,--gc-sections"
make DESTDIR="$(pwd)/install" install
popd # psmisc-${psmisc_version}

popd # build

shopt -s extglob

echo "= extracting psmisc binary"
mv build/psmisc-${psmisc_version}/install/usr/local/bin/* release 2>/dev/null
mv build/psmisc-${psmisc_version}/install/usr/local/sbin/* release 2>/dev/null

echo "= striptease"
for file in release/*
  do
      strip -s -R .comment -R .gnu.version --strip-unneeded "$file" 2>/dev/null
done

if [[ "$WITH_UPX" == 1 && -x "$(which upx 2>/dev/null)" ]]
    then
        echo "= upx compressing"
        for file in release/*
          do
              upx -9 --best "$file" 2>/dev/null
        done
fi

echo "= create release tar.xz"
tar --xz -acf psmisc-static-v${psmisc_version}-${platform_arch}.tar.xz release
# cp psmisc-static-*.tar.xz /root 2>/dev/null

if [ "$NO_CLEANUP" != 1 ]
    then
        echo "= cleanup"
        rm -rf release build
fi

echo "= psmisc v${psmisc_version} done"
