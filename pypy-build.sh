#!/bin/bash -eu

source pypy-versions.txt
# Provides:
# PYPY_MAJOR_VERSION
# PYPY_BUILD_DEP_VERSION

PACKAGE="tklbam-pypy2"

PYPY_REPO="https://github.com/pypy/pypy"
PYPY_BRANCH="release-pypy2.7-v${PYPY_MAJOR_VERSION}.x"

PYPY_URL="https://downloads.python.org/pypy"
PYPY_RELEASE_URL="${PYPY_URL}/pypy2.7-v${PYPY_BUILD_DEP_VERSION}-linux64.tar.bz2"

BUILD_ROOT="$(pwd)/build"
PYPY_SRC="${BUILD_ROOT}/pypy-src"
PYPY_BIN="${BUILD_ROOT}/pypy-bin"
PYPY_BUILD="${BUILD_ROOT}/pypy-build"

mkdir "$BUILD_ROOT"
mkdir "$PYPY_BUILD"
cd "$BUILD_ROOT"

git clone --depth=1 "${PYPY_REPO}" -b "${PYPY_BRANCH}" pypy-src
read -r local_commit_id < src-commit-id.txt

cloned_commit_id=$(git --git-dir=pypy-src/.git rev-parse HEAD)
if [[ "$local_commit_id" != "$cloned_commit_id" ]]; then
    echo "source commit ID does not match" >&2
    exit 1
fi

curl "$PYPY_RELEASE_URL" -o pypy-bin.tar.bz2
read -ra local_checksum < checksum.txt
read -ra dl_checksum <<<"$(sha256sum pypy-bin.tar.bz2)"
if [[ "${local_checksum[*]}" != "${dl_checksum[*]}" ]]; then
    echo "Checksums for pypy-bin.tar.bz2 do not match" >&2
    exit 1
fi

tar -xvf pypy-bin.tar.bz2
mv pypy2.7-* pypy-bin
rm pypy-bin.tar.bz2

cd "$PYPY_SRC"
git submodule update --init --recursive --depth=1
cd "pypy/goal"

echo "### Building Pypy - stage 1"
PYPY="${PYPY_BIN}/bin/pypy"

# --gc=incminimark here is required for the cpyext (or whatever it is, the
#   thing required for linking C against it) to work.
#
# this will error on tkinter, but it's fine, it will do everything it needs to
"${PYPY}" ../../rpython/bin/rpython \
    --gc=incminimark \
    -Osize targetpypystandalone

cd "${PYPY_SRC}/pypy/tool/release"

echo "### Building Pypy - stage 2"
mkdir "$PYPY_BUILD"
"${PYPY}" package.py \
    --without-_tkinter \
    --no-keep-debug \
    --archive-name "$PACKAGE" \
    --builddir "$PYPY_BUILD"

echo "### Minimizing so files"
find "$PYPY_BUILD" -type f -iname '*.so' -exec strip -s {} \;
find "$PYPY_BUILD" -type f -iname '*.so' -exec upx-ucl --best {} \;

# result is "/tmp/pypy-build/pypy-turnkeylinux" there is a .tar.bz2 file there
# I forgot to remove but that DOES NOT include the stripped & packed binaries,
# use the raw dir tree instead
