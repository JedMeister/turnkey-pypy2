#!/bin/bash -eu

source pypy-versions.txt
# Provides:
# PYTHON_VERSION
# PYPY_MAJOR_VERSION
# PYPY_BUILD_DEP_VERSION

PYPY_SOURCE_V="pypy$PYTHON_VERSION-v${PYPY_MAJOR_VERSION}.x"
PYPY_PREBUILT="pypy$PYTHON_VERSION-v${PYPY_BUILD_DEP_VERSION}"

BUILD_ROOT="$PWD/build"
PYPY_SRC="$BUILD_ROOT/source"
PYPY_BIN="$BUILD_ROOT/download"
PYPY_BUILD="$BUILD_ROOT/local-build"

fatal() { echo "FATAL: $*" >&2; exit 1; }
info() {
    local msg="$*"
    local len="${#msg}"
    # shellcheck disable=SC2183
    printf '%*s' "$len" | tr " " "#"
    echo -e "\n$msg"
    # shellcheck disable=SC2183
    printf '%*s' "$len" | tr " " "#"
    echo
}

info "### Starting build; BUILD_ROOT=$BUILD_ROOT ###"

mkdir -p "${BUILD_ROOT}" 

info "### Cloning and verifying source ###"

pypy_repo="https://github.com/pypy/pypy"
pypy_branch="release-$PYPY_SOURCE_V"
git clone --depth=1 "${pypy_repo}" -b "${pypy_branch}" "$PYPY_SRC"
read -r local_commit_id < src-commit-id.txt

cloned_commit_id=$(git --git-dir="$PYPY_SRC"/.git rev-parse HEAD)
if [[ "$local_commit_id" != "$cloned_commit_id" ]]; then
    fatal "source commit ID does not match"
fi

info "### Downloading and verifying pre-built binary archive ###"

case $(dpkg --print-architecture) in
    amd64)
        read -ra local_checksum < checksum-amd64.txt
        pypy_arch="linux64";;
    arm64)
        read -ra local_checksum < checksum-arm64.txt
        pypy_arch="aarch64";;
    *)
        fatal "host architecture unsupported";;
esac

pypy_url="https://downloads.python.org/pypy"
pypy_tarball="${PYPY_PREBUILT}-${pypy_arch}.tar.bz2"
pypy_release_url="${pypy_url}/${pypy_tarball}"
curl "$pypy_release_url" -o pypy-bin.tar.bz2
read -ra dl_checksum <<<"$(sha256sum pypy-bin.tar.bz2)"
if [[ "${local_checksum[*]}" != "${dl_checksum[*]}" ]]; then
    fatal "Checksums for pypy-bin.tar.bz2 do not match"
fi

info "### Unpacking pre-built archive & cloning source submodules ###"

tar -xf pypy-bin.tar.bz2
mv pypy2.7-* "$PYPY_BIN"

cd "$PYPY_SRC"
git submodule update --init --recursive --depth=1
cd "pypy/goal"

echo "done..."

info "### Building PyPy package source - stage 1 - common ###"

PYPY="${PYPY_BIN}/bin/pypy"
# pypy can't find it's lib during build
# not sure why, but setting the lib path resolves it
export LD_LIBRARY_PATH="${PYPY_BIN}/bin"

# --gc=incminimark here is required for C code linking
"${PYPY}" ../../rpython/bin/rpython \
    --gc=incminimark \
    -Osize targetpypystandalone

ls -la "/tmp/usession-release-pypy2.7-v${PYPY_BUILD_DEP_VERSION}-0"
cd "${PYPY_SRC}/pypy/tool/release"

for build in dbg full; do
    rm -rf "${PYPY_BUILD:?}"
    mkdir "$PYPY_BUILD"
    x=2
    package_name="tklbam-pypy2-$build"
    build_args=(--without-_tkinter --without-sqlite3)
    if [[ "$build" == "full" ]]; then
        build_args+=(--no-keep-debug)
        x=3
    fi

    info "### Building PyPy package source - stage $x - $package_name ###"

    build_args+=(--archive-name "$package_name" --builddir "$PYPY_BUILD")
    echo "- build command: $PYPY package.py ${build_args[*]}"
    "$PYPY" package.py "${build_args[@]}"

    if [[ "$build" == "full" ]]; then
        echo "### Minimizing so files ###"
        find "$PYPY_BUILD" -type f -iname '*.so' -exec strip -s {} \;
        find "$PYPY_BUILD" -type f -iname '*.so' -exec upx-ucl --best {} \;
    fi
    echo "- moving $PYPY_BUILD/$package_name to $BUILD_ROOT/"
    mv "$PYPY_BUILD/$package_name" "$BUILD_ROOT/"
done

info "### Building PyPy package source - stage 4 - tklbam-pypy2 (minimal) ###"
package_name=tklbam-pypy2  # name of minimal package
pkg_src_path="$BUILD_ROOT/$package_name"

# create tree of hardlinked files
cp -lr "$pkg_src_path-full" "$pkg_src_path"

# there may be more to remove, e.g. non linux platform (plat-*) lib
# but beyond these it gets risky... even removing lib-tk may not be ideal?!
to_remove=(
    "idlelib"
    "test"
    "tests"
    "plat-aix3"
    "plat-aix4"
    "plat-atheos"
    "plat-beos5"
    "plat-darwin"
    "plat-freebsd4"
    "plat-freebsd5"
    "plat-freebsd6"
    "plat-freebsd7"
    "plat-freebsd8"
    "plat-irix5"
    "plat-irix6"
    "plat-mac"
    "plat-netbsd1"
    "plat-next3"
    "plat-os2emx"
    "plat-riscos"
    "plat-sunos5"
    "plat-unixware7"
)
# if we want/need to keep 'idlelib', swap it for 'idle_test'

echo -e "\n# removing libraries: ${to_remove[*]}\n"
for to_rm in "${to_remove[@]}"; do
    readarray -t found <<< \
        "$(find "$pkg_src_path" -type d -name "$to_rm")"
    for dir in "${found[@]}"; do
        if [[ -n "$dir" ]]; then
            echo "# - removing $dir"
            rm -r "$dir"
        else
            echo "*** WARNING: no result for $to_rm - skipping..." >&2
        fi
    done
done

info "### Successfully built TurnKey PyPy package source ###"
