#!/bin/bash

SCRIPT_REPO="https://git.code.sf.net/p/soxr/code"
SCRIPT_COMMIT="945b592b70470e29f917f4de89b4281fbbd540c0"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    if [[ $TARGET == darwin* ]]; then
        git config user.name "iconik"
        git config user.email "info@iconik.io"
        for patch in $ROOT_DIR/patches/soxr/*.patch; do
            echo "Applying $patch"
            git am < "$patch"
        done
    fi
    mkdir build && cd build

    local myconf=(
        -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX"
        -DBUILD_SHARED_LIBS=OFF
        -DBUILD_TESTS=OFF
        -DBUILD_EXAMPLES=OFF
        -DWITH_OPENMP="$([[ $TARGET == winarm64 ]] && echo OFF || echo ON)"
    )

    if [[ $TARGET == darwin* ]]; then
        export CFLAGS="$CFLAGS -Xpreprocessor -fopenmp -I/opt/homebrew/opt/libomp/include" # for libomp, needs fixing
        export LDFLAGS="$LDFLAGS /opt/homebrew/opt/libomp/lib/libomp.a"
        myconf+=( -DCMAKE_POLICY_VERSION_MINIMUM=3.5 )
    fi

#    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
#        -DWITH_OPENMP="$([[ $TARGET == winarm64 ]] && echo OFF || echo ON)" \
#        -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_SHARED_LIBS=OFF \
#        ..
    cmake "${myconf[@]}" ..
    make -j$(nproc)
    make install

    if [[ $TARGET == darwin* ]]; then
        echo "Libs.private: $FFBUILD_PREFIX/lib/libomp.a" >> "$FFBUILD_PREFIX"/lib/pkgconfig/soxr.pc
    elif [[ $TARGET != winarm64 ]]; then
        echo "Libs.private: -lgomp" >> "$FFBUILD_PREFIX"/lib/pkgconfig/soxr.pc
    fi
}

ffbuild_configure() {
    echo --enable-libsoxr
}

ffbuild_unconfigure() {
    echo --disable-libsoxr
}

ffbuild_ldflags() {
    echo -pthread
}

ffbuild_libs() {
    if [[ $TARGET == darwin* ]]; then
        echo -lomp
    elif [[ $TARGET != winarm64 ]]; then
        echo -lgomp
    fi
}
