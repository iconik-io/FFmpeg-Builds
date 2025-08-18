#!/bin/bash

SCRIPT_REPO="https://github.com/xiph/vorbis.git"
SCRIPT_COMMIT="84c023699cdf023a32fa4ded32019f194afcdad0"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    if [[ $TARGET == darwin* ]]; then
        echo "remove force_cpusubtype_ALL from configure.ac"
        sed -i.bak 's/-force_cpusubtype_ALL//g' configure.ac
    fi
    ./autogen.sh

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --disable-shared
        --enable-static
        --disable-oggtest
    )

    if [[ $TARGET == win* || $TARGET == linux* ]]; then
        myconf+=(
            --host="$FFBUILD_TOOLCHAIN"
        )
    elif [[ $TARGET == darwin* ]]; then
        echo "not cross compiling"
    else
        echo "Unknown target"
        return -1
    fi

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install
}

ffbuild_configure() {
    echo --enable-libvorbis
}

ffbuild_unconfigure() {
    echo --disable-libvorbis
}
