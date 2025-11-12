PYPY_REPO="https://github.com/pypy/pypy"
PYPY_BRANCH="release-pypy2.7-v7.x"
PYPY_RELEASE_URL="https://downloads.python.org/pypy/pypy2.7-v7.3.20-linux64.tar.bz2"

REQUIRED_LIBS=("gcc" "libffi-dev" "pkgconf" "libexpat1-dev" "zlib1g-dev" "libncurses-dev" "libbz2-dev" "libssl-dev" "libsqlite3-dev" "libgdbm-dev")

for pkg in "${REQUIRED_LIBS[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    echo "pkg not installed: $pkg" >&2
    exit 1
  fi
done
echo "all required dev packages installed"

mkdir "pypy-build"
cd "pypy-build"

BUILD_ROOT="$(pwd)"
PYPY_SRC="${BUILD_ROOT}/pypy-src"
PYPY_BIN="${BUILD_ROOT}/pypy-bin"

git clone --depth=1 "${PYPY_REPO}" -b "${PYPY_BRANCH}" pypy-src
wget "$PYPY_RELEASE_URL" -O pypy-bin.tar.bz2
tar -xvf pypy-bin.tar.bz2
mv pypy2.7-* pypy-bin
rm pypy-bin.tar.bz2

cd "$PYPY_SRC"
git submodule update --init --recursive --depth=1
cd "pypy/goal"

# --gc=incminimark here is required for the cpyext (or whatever it is, the thing required for linking C against it) to work.
#
# this will error on tkinter, but it's fine, it will do everything it needs too
"${PYPY_BIN}/bin/pypy" ../../rpython/bin/rpython --gc=incminimark -Osize targetpypystandalone

cd "${PYPY_SRC}/pypy/tool/release"
rm -rf /tmp/pypy-build
mkdir /tmp/pypy-build

"${PYPY_BIN}/bin/pypy" package.py --without-_tkinter --no-keep-debug --archive-name pypy-turnkeylinux --builddir /tmp/pypy-build

find "/tmp/pypy-build" -type f -iname '*.so' -exec strip -s {} \;
find "/tmp/pypy-build" -type f -iname '*.so' -exec upx --best {} \;

# result is "/tmp/pypy-build/pypy-turnkeylinux" there is a .tar.bz2 file there I forgot to remove
# but that DOES NOT include the stripped & packed binaries, use the raw dir tree instead

#1. get pypy src (if getting from git, this has required submodules)
#2. get pypy bin
#3. install gcc libffi-dev pkgconf libexpat1-dev zlib1g-devA libncurses5-dev libbz2-dev libssl-dev libsqlite3-dev libgdbm-dev
#4. ``cd ${pypy_src}/pypy/goal``
#5. ``$(pypy_bin_path) ../../rpython/bin/rpython --gc=incminimark -Osize targetpypystandalone``
#6. ``strip -s libpypy-c.so``
#7. ``upx --best libpypy-c.so``
#8. ``cd ${pypy_src}/pypy/tool/release``
#9. ``$(pypy_bin_path) package.py --without-_tkinter --no-keep-debug --archive-name pypy-turnkeylinux``
