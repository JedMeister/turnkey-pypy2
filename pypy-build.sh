#!/bin/bash -eu

source pypy-versions.txt
# Provides:
# PYTHON_VERSION
# PYPY_MAJOR_VERSION
# PYPY_BUILD_DEP_VERSION

PYPY_SOURCE_V="pypy$PYTHON_VERSION-v${PYPY_MAJOR_VERSION}.x"
PYPY_PREBUILT="pypy$PYTHON_VERSION-v${PYPY_BUILD_DEP_VERSION}"

BUILD_ROOT="$(pwd)/build"
PYPY_SRC="${BUILD_ROOT}/pypy-src"
PYPY_BIN="${BUILD_ROOT}/pypy-bin"
PYPY_BUILD="${BUILD_ROOT}/pypy-build"

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

info "### Cloning and verifying source ###"

pypy_repo="https://github.com/pypy/pypy"
pypy_branch="release-$PYPY_SOURCE_V"
git clone --depth=1 "${pypy_repo}" -b "${pypy_branch}" pypy-src
read -r local_commit_id < src-commit-id.txt

cloned_commit_id=$(git --git-dir=pypy-src/.git rev-parse HEAD)
if [[ "$local_commit_id" != "$cloned_commit_id" ]]; then
    fatal "source commit ID does not match"
fi

info "### Downloading and verifying pre-built binary archive ###"

case $(dpkg --print-architecture) in
    amd64)
        pypy_arch="linux64";;
    arm64)
        pypy_arch="aarch64";;
    *)
        fatal "host architecture unsupported";;
esac

pypy_url="https://downloads.python.org/pypy"
pypy_tarball="${PYPY_PREBUILT}-${pypy_arch}.tar.bz2"
pypy_release_url="${pypy_url}/${pypy_tarball}"
curl "$pypy_release_url" -o pypy-bin.tar.bz2
read -ra local_checksum < checksum.txt
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

info "### Building PyPy package source - stage 1 - common ###"

PYPY="${PYPY_BIN}/bin/pypy"
# pypy can't find it's lib during build
# not sure why, but setting the lib path resolves it
export LD_LIBRARY_PATH="${PYPY_BIN}/bin"

# --gc=incminimark here is required for C code linking
"${PYPY}" ../../rpython/bin/rpython \
    --gc=incminimark \
    -Osize targetpypystandalone

cd "${PYPY_SRC}/pypy/tool/release"

for build in dbg full; do
    x=2
    package_name="tklbam-pypy2-$build"
    build_args=(--without-_tkinter --without-sqlite3)
    if [[ "$build" == "full" ]]; then
        build_args+=(--no-keep-debug)
        x=3
    fi
    rm -rf "${PYPY_BUILD:?}/*"
    mkdir -p "$PYPY_BUILD/$build"

    info "### Building PyPy package source - stage $x - $package_name ###"

    "${PYPY}" package.py "${build_args[@]}" \
        --archive-name "$package_name" \
        --builddir "$PYPY_BUILD/$build"

    if [[ "$build" == "full" ]]; then
        echo "### Minimizing so files ###"
        find "$PYPY_BUILD/full" -type f -iname '*.so' -exec strip -s {} \;
        find "$PYPY_BUILD/full" -type f -iname '*.so' -exec upx-ucl --best {} \;
    fi
    mv "$PYPY_BUILD/$build/$package_name" "$BASE_DIR/"
done

info "### Building PyPy package source - stage 4 - tklbam-pypy2 (minimal) ###"
package_name=tklbam-pypy2
pkg_src_path="$BASE_DIR/$package_name"
cp -lr "$pkg_src_path-full" "$pkg_src_path"

# there may be more to remove, e.g. non linux platform (plat-*) lib
# but beyond these it gets risky... even removing lib-tk may not be ideal?!
to_remove=( "lib-tk" "idlelib" "email" "test" "tests" )
# if we want/need to keep 'idlelib', swap it for 'idle_test'

echo -e "\n# removing libraries: ${to_remove[*]}\n"
for to_rm in "${to_remove[@]}"; do
    readarray -t found <<< \
        "$(find "$" -type d -name "$to_rm")"
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
