#!/bin/bash -eu

source pypy-versions.txt
# Provides:
# PYPY_MAJOR_VERSION
# PYPY_BUILD_DEP_VERSION

PYPY_REPO="https://github.com/pypy/pypy"
PYPY_BRANCH="release-pypy2.7-v${PYPY_MAJOR_VERSION}.x"

PYPY_URL="https://downloads.python.org/pypy"
PYPY_RELEASE_URL="${PYPY_URL}/pypy2.7-v${PYPY_BUILD_DEP_VERSION}-linux64.tar.bz2"

mkdir -p "pypy-build"
cd "pypy-build"

BUILD_ROOT="$(pwd)"
PYPY_SRC="${BUILD_ROOT}/pypy-src"
PYPY_BIN="${BUILD_ROOT}/pypy-bin"

[[ -d "$PYPY_SRC" ]] \
    || git clone --depth=1 "${PYPY_REPO}" -b "${PYPY_BRANCH}" pypy-src

[[ -f pypy-bin.tar.bz2 ]] || wget "$PYPY_RELEASE_URL" -O pypy-bin.tar.bz2

[[ -d pypy-bin ]] || tar -xvf pypy-bin.tar.bz2 && mv pypy2.7-* pypy-bin

cd "$PYPY_SRC"
git submodule update --init --recursive --depth=1
cd "pypy/goal"

PYPY="${PYPY_BIN}/bin/pypy"

# --gc=incminimark here is required for the cpyext (or whatever it is, the
#   thing required for linking C against it) to work.
#
# this will error on tkinter, but it's fine, it will do everything it needs too
"${PYPY}" ../../rpython/bin/rpython --gc=incminimark -Osize targetpypystandalone

cd "${PYPY_SRC}/pypy/tool/release"
rm -rf /tmp/pypy-build
mkdir /tmp/pypy-build

"${PYPY}" package.py \
    --without-_tkinter \
    --no-keep-debug \
    --archive-name pypy-turnkeylinux \
    --builddir /tmp/pypy-build

find "/tmp/pypy-build" -type f -iname '*.so' -exec strip -s {} \;
find "/tmp/pypy-build" -type f -iname '*.so' -exec upx-ucl --best {} \;

# result is "/tmp/pypy-build/pypy-turnkeylinux" there is a .tar.bz2 file there
# I forgot to remove but that DOES NOT include the stripped & packed binaries,
# use the raw dir tree instead
