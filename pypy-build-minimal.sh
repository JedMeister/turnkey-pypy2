#!/bin/bash -eu

PYPY_BUILT="$PWD/pypy-build"
PYPY_FULL="$PYPY_BUILT/tklbam-pypy2-full"
PYPY_MIN="$PYPY_BUILT/tklbam-pypy2"

echo "### Creating hardlinked file tree for minimal package"
cp -lr "$PYPY_FULL" "$PYPY_MIN"

# there may be more to remove, but beyond these it gets risky...
# (perhaps even anything more than test/s is risky?)
UNNEEDED=( "lib-tk" "idlelib" "email" "test" "tests" )
# if we decide that we want/need to keep 'idlelib', swap it for 'idle_test'

echo "### Removing files/libraries for minimal package"
for to_rm in "${UNNEEDED[@]}"; do
    readarray -t found <<< \
        "$(find "$PYPY_MIN" -type d -name "$to_rm")"
    for dir in "${found[@]}"; do
        if [[ -n "$dir" ]]; then
            echo "### - removing $dir"
            rm -r "$dir"
        else
            echo "*** error: no result for $to_rm - skipping..." >&2
        fi
    done
done
