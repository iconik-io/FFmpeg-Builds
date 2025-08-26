#!/bin/bash
set -e
cd "$(dirname "$0")"
source util/vars.sh

PYTHON=$(pyenv root)/versions/3.12.9/bin/python3
$PYTHON -m venv --clear py_build_env
source py_build_env/bin/activate
python -m pip install -r requirements_macos.txt
export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
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

layername() {
    printf "layer-"
    basename "$1" | sed 's/.sh$//'
}

to_df() {
    _of="${TODF:-Dockerfile}"
    printf "$@" >> "$_of"
    echo >> "$_of"
}

to_script() {
    _of="${SCRIPT_FILE:-build_conf.sh}"
    printf "%s\n" "$@" >> "$_of"
}

exec_dockerstage() {
    SCRIPT="$1"
    (
        SELF="$SCRIPT"
        STAGENAME="$(basename "$SCRIPT" | sed 's/.sh$//')"
        source util/dl_functions.sh
        source "$SCRIPT"

        ffbuild_enabled || exit 0

        STG="$(ffbuild_dockerdl)"
        if [[ -n "$STG" ]]; then
            HASH="$(sha256sum <<<"$STG" | cut -d" " -f1)"
            export SELFCACHE=".cache/downloads/${STAGENAME}_${HASH}.tar.xz"
        fi

        ffbuild_dockerstage || exit $?
    )
}

exec_build_dep() {
    SCRIPT="$1"
    (
        SELF="$SCRIPT"
        export STAGENAME="$(basename "$SCRIPT" | sed 's/.sh$//')"
        source util/dl_functions.sh
        source "$SCRIPT"

        ffbuild_enabled || exit 0

        export STAGEDIR="${DEPSDIR}${STAGENAME}"
        if [[ -d $STAGEDIR ]]; then
          exit 0
        fi
        mkdir -p $STAGEDIR

        STG="$(ffbuild_dockerdl)"
        if [[ -n "$STG" ]]; then
            HASH="$(sha256sum <<<"$STG" | cut -d" " -f1)"
            export SELFCACHE="$(pwd)/.cache/downloads/${STAGENAME}_${HASH}.tar.xz"
        fi

        util/run_stage_local.sh "$SCRIPT" || exit $?
    )
}

for ID in $(ls -1d scripts.d/??-* | sed 's|^.*/\(..\).*|\1|' | sort -u); do

    for STAGE in scripts.d/$ID-*; do

        if [[ -f "$STAGE" ]]; then
            exec_build_dep "$STAGE"
        else
            for STAGE in "${STAGE}"/??-*; do
                exec_build_dep "$STAGE"
            done
        fi
    done
done

get_output() {
    (
        SELF="$1"
        source $1
        if ffbuild_enabled; then
            ffbuild_$2 || exit 0
        else
            ffbuild_un$2 || exit 0
        fi
    )
}

source "variants/${TARGET}-${VARIANT}.sh"

for addin in ${ADDINS[*]}; do
    source "addins/${addin}.sh"
done

for script in scripts.d/**/*.sh; do
    FF_CONFIGURE+=" $(get_output $script configure)"
    FF_CFLAGS+=" $(get_output $script cflags)"
    FF_CXXFLAGS+=" $(get_output $script cxxflags)"
    FF_LDFLAGS+=" $(get_output $script ldflags)"
    FF_LDEXEFLAGS+=" $(get_output $script ldexeflags)"
    FF_LIBS+=" $(get_output $script libs)"
done
for script in scripts.d/*.sh; do
    FF_CONFIGURE+=" $(get_output $script configure)"
    FF_CFLAGS+=" $(get_output $script cflags)"
    FF_CXXFLAGS+=" $(get_output $script cxxflags)"
    FF_LDFLAGS+=" $(get_output $script ldflags)"
    FF_LDEXEFLAGS+=" $(get_output $script ldexeflags)"
    FF_LIBS+=" $(get_output $script libs)"
done

FF_CONFIGURE="$(xargs <<< "$FF_CONFIGURE")"
FF_CFLAGS="$(xargs <<< "$FF_CFLAGS")"
FF_CXXFLAGS="$(xargs <<< "$FF_CXXFLAGS")"
FF_LDFLAGS="$(xargs <<< "$FF_LDFLAGS")"
FF_LDEXEFLAGS="$(xargs <<< "$FF_LDEXEFLAGS")"
FF_LIBS="$(xargs <<< "$FF_LIBS")"
echo "FF_CONFIGURE: $FF_CONFIGURE"
echo "FF_CFLAGS: $FF_CFLAGS"
echo "FF_CXXFLAGS: $FF_CXXFLAGS"
echo "FF_LDFLAGS: $FF_LDFLAGS"
echo "FF_LDEXEFLAGS: $FF_LDEXEFLAGS"
echo "FF_LIBS: $FF_LIBS"

to_script "FF_CONFIGURE=\"$FF_CONFIGURE\""
to_script "FF_CFLAGS=\"$FF_CFLAGS\""
to_script "FF_CXXFLAGS=\"$FF_CXXFLAGS\""
to_script "FF_LDFLAGS=\"$FF_LDFLAGS\""
to_script "FF_LDEXEFLAGS=\"$FF_LDEXEFLAGS\""
to_script "FF_LIBS=\"$FF_LIBS\""
