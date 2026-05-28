PyPy 2.7 - Used for TKLBAM
==========================

Unfortunately TKLBAM is _still_ in Python2. Ideally we should update it to
python3, but until then we use [pypy](https://pypy.org/). Even though Python2
is EOL, PyPy still maintain their Python2 build.

This repo builds a Debian package of pypy2 for use by TKLBAM. The packaging is
a bit hacky and nothing close to meeting Debian policy, but for our purposes
it's "good enough"...

Update PyPy
===========

Check upstream version
----------------------

To build PyPy from source, python2 is required. We do that by downloading the
pre-compiled binary provided by upstream.

Compare the PYPY_BUILD_DEP_VERSION in pypy-versions.txt against the latest
upstream PyPy stable pypy2 release here:

https://downloads.python.org/pypy/

That will determine the pre-compiled version that is downloaded at build time.

Update upstream version
-----------------------

If there is a newer version, first update the value of PYPY_BUILD_DEP_VERSION
in pypy-versions.txt.

Then update the checksums in the 2 checksum files:

with the relevant checksums
for
the newer download - be sure to the 'pypy2.7-vXXX' checksum for:

- checksum-amd64.txt (with checksum for linux64.tar.bz2)
- checksum-arm64.txt (with checksum for aarch64.tar.bz2)

The checksums can be found here:

https://pypy.org/checksums.html

Note that we use the .tar.bz2 tarball but ONLY the checksum should be replaced
in those files - the noted file name ('pypy-bin.tar.bz2') should not be
changed.

Update source version
---------------------

The latest stable source will automatically be pulled from their git source.
However as an additional check, we also double check the git commit ID of the
matching version.

To get the commit ID, check the PyPy source releases page for the latest
stable release - it should generally match the version of the precompiled
source - as discussed above.

https://github.com/pypy/pypy/releases/tag/

Once you have the matching version, ensure that you update the commit ID in the
'src-commit-id.txt' file.

FWIW I usually right click on the short commit ID on the release page. Then
"copy link" and paste the whole URL into the file and then remove everything
but the SHA.

Build
-----

Assuming building with pool with everything set up ready to go, before running
'pool-get . turnkey-pypy2' be sure to load the relevant deckdebuild env vars.

An easy way to do that is to just source the 'DECKDEBUILD_ENV' file in the repo
prior to running pool-get. Alternatively, you can just prefix the pool command:

```
DECKDEBUILD_FAKETIME=false DECKDEBUILD_MOUNT_PROC=true pool-get . turnkey-pypy2
```

If you do not set those vars (which as the var names suggest; disable faketime
& mount /proc), the build will fail.
in the git repo.
