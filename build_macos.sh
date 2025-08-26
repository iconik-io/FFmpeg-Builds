#!/bin/bash
set -xe
cd "$(dirname "$0")"
source util/vars.sh

export PATH="$HOME/.cargo/bin:$PATH"
export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
source py_build_env/bin/activate
export RUN_IN_DOCKER=$(false)

source "variants/${TARGET}-${VARIANT}.sh"
source build_conf.sh
export LC_ALL=en_US.UTF-8
export ROOT_DIR="$(pwd)"
export FFBUILD_PREFIX="$(pwd)/build/output"
export DEPSDIR="$(pwd)/build/deps/"
mkdir -p $DEPSDIR
export PKG_CONFIG_LIBDIR=$FFBUILD_PREFIX/lib/pkgconfig:$FFBUILD_PREFIX/share/pkgconfig
export CC="gcc"
export CXX="g++"
export CFLAGS="-I$FFBUILD_PREFIX/include -O2 -pipe -march=armv8-a -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -pthread"
export CXXFLAGS="-I$FFBUILD_PREFIX/include -O2 -pipe -march=armv8-a -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -pthread"
export LDFLAGS="-L$FFBUILD_PREFIX/lib -O2 -pipe -march=armv8-a -fstack-protector-strong -pthread -lm"
export STAGE_CFLAGS="-fvisibility=hidden"
export STAGE_CXXFLAGS="-fvisibility=hidden"
export TARGET="$TARGET"
export VARIANT="$VARIANT"
export LIBTOOL=glibtool
export LIBTOOLIZE=glibtoolize
export RANLIB=ranlib
export AR=ar
export CFLAGS="$CFLAGS -Xpreprocessor -fopenmp -I/opt/homebrew/opt/libomp/include" # for libomp, needs fixing
export LDFLAGS="$LDFLAGS /opt/homebrew/opt/libomp/lib/libomp.a"

for addin in ${ADDINS[*]}; do
    source "addins/${addin}.sh"
done

rm -rf ffbuild
mkdir -p ffbuild

FFMPEG_REPO="${FFMPEG_REPO:-https://github.com/FFmpeg/FFmpeg.git}"
FFMPEG_REPO="${FFMPEG_REPO_OVERRIDE:-$FFMPEG_REPO}"
GIT_BRANCH="${GIT_BRANCH:-master}"
GIT_BRANCH="${GIT_BRANCH_OVERRIDE:-$GIT_BRANCH}"

BUILD_SCRIPT="build_osx.sh"
trap "rm -f -- '$BUILD_SCRIPT'" EXIT

echo "ff configure flags are: $FF_CONFIGURE"

cat <<EOF >"$BUILD_SCRIPT"
    set -xe
    cd ffbuild
    rm -rf ffmpeg prefix

    git clone --filter=blob:none --branch='$GIT_BRANCH' '$FFMPEG_REPO' ffmpeg
    cd ffmpeg

    ./configure --prefix=ffbuild/prefix --pkg-config-flags="--static" $FFBUILD_TARGET_FLAGS $FF_CONFIGURE \
        --extra-cflags="$FF_CFLAGS" --extra-cxxflags="$FF_CXXFLAGS" --extra-libs="$FF_LIBS" \
        --extra-ldflags="$FF_LDFLAGS" --extra-ldexeflags="$FF_LDEXEFLAGS" \
        --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --nm="$NM" \
        --extra-version="\$(date +%Y%m%d)"
    make -j\$(nproc) V=1
    make install
EOF

bash "$BUILD_SCRIPT"

mkdir -p artifacts
ARTIFACTS_PATH="$PWD/artifacts"
BUILD_NAME="ffmpeg-$(./ffbuild/ffmpeg/ffbuild/version.sh ffbuild/ffmpeg)-${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}"

mkdir -p "ffbuild/pkgroot/$BUILD_NAME"
cd ffbuild/ffmpeg
package_variant ffbuild/prefix "$ROOT_DIR/ffbuild/pkgroot/$BUILD_NAME"
cd -

[[ -n "$LICENSE_FILE" ]] && cp "ffbuild/ffmpeg/$LICENSE_FILE" "ffbuild/pkgroot/$BUILD_NAME/LICENSE.txt"

cd ffbuild/pkgroot

OUTPUT_FNAME="${BUILD_NAME}.tar.xz"
tar cJf ${ARTIFACTS_PATH}/${OUTPUT_FNAME} "$BUILD_NAME"

cd -

rm -rf ffbuild
