#!/bin/bash

SCRIPT_REPO="https://github.com/FFTW/fftw3.git"
SCRIPT_COMMIT="816722732224231e90e634b5839bb7808cddc6cd"
SCRIPT_TARBALL="https://www.fftw.org/fftw-3.3.10.tar.gz"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerdl() {
    echo "wget -O- "$SCRIPT_TARBALL" | tar xz --strip-components=1"
}

ffbuild_dockerbuild() {
    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --disable-shared
        --enable-static
        --disable-fortran
        --disable-doc
        --with-our-malloc
        --enable-threads
        --with-combined-threads
        --with-incoming-stack-boundary=2
    )

    if [[ $TARGET != *arm64 ]]; then
        myconf+=(
            --enable-sse2
            --enable-avx
            --enable-avx2
        )
    fi

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

#    sed -i 's/windows.h/process.h/' configure.ac

#    ./bootstrap.sh "${myconf[@]}"
    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install
}
