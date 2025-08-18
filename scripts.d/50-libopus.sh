#!/bin/bash

SCRIPT_REPO="https://github.com/xiph/opus.git"
SCRIPT_COMMIT="2941f08a616290f291579df9c8dbc0801d8d3f18"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerdl() {
    default_dl .
    if [[ $TARGET != darwin* ]]; then
        echo "./autogen.sh"
    fi
}

ffbuild_dockerbuild() {

    if [[ $TARGET == darwin* ]]; then
        ./autogen.sh
    fi
    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --disable-shared
        --enable-static
        --disable-extra-programs
    )

    if [[ $TARGET == winarm* ]]; then
        myconf+=(
            --disable-rtcd
        )
    fi
    if [[ $TARGET == win* || $TARGET == linux* ]]; then
        myconf+=(
            --host="$FFBUILD_TOOLCHAIN"
        )
    fi

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install
}

ffbuild_configure() {
    echo --enable-libopus
}

ffbuild_unconfigure() {
    echo --disable-libopus
}
