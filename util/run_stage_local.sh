#!/bin/bash
set -xe

export RAW_CFLAGS="$CFLAGS"
export RAW_CXXFLAGS="$CXXFLAGS"
export RAW_LDFLAGS="$LDFLAGS"
[[ -n "$STAGE_CFLAGS" ]] && export CFLAGS="$CFLAGS $STAGE_CFLAGS"
[[ -n "$STAGE_CXXFLAGS" ]] && export CXXFLAGS="$CXXFLAGS $STAGE_CXXFLAGS"
[[ -n "$STAGE_LDFLAGS" ]] && export LDFLAGS="$LDFLAGS $STAGE_LDFLAGS"

source "$1"

cd $STAGEDIR
echo "Running stage: $STAGENAME"
echo "cache file $SELFCACHE"

if [[ -n "$STAGENAME" && -f $SELFCACHE ]]; then
    mkdir -p "$STAGENAME"
    tar xf $SELFCACHE -C "$STAGENAME"
    cd "$STAGENAME"
elif [[ -n "$STAGENAME" ]]; then
    mkdir -p "$STAGENAME"
    cd "$STAGENAME"
fi

echo "Current directory: $PWD"
if [ "$(find . -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ]; then
    dir=$(find . -mindepth 1 -maxdepth 1 -type d)
    cd "$dir"
fi
git config --global --add safe.directory "$PWD"

if [[ -z "$2" ]]; then
    ffbuild_dockerbuild
else
    "$2"
fi
rm -rf "$FFBUILD_PREFIX"/bin

if [[ -n "$STAGENAME" ]]; then
    rm -rf "$STAGENAME"
fi
