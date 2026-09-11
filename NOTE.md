# Developing with `stash2`

`stash2/` is a local, gitignored alternative to `stash/` for day-to-day
development. Instead of the pinned submodule commits in `stash/`, it holds
symlinks to your own working checkouts of each dependency, so you can edit a
dependency and rebuild the example against your changes immediately, without
bumping submodule pointers or committing anything.

It is never committed (`.gitignore` excludes `/stash2/`) and is not part of
the published project layout — it's purely local.

## Set it up

Create `stash2/` with one symlink per dependency, pointing at your own
checkouts:

```sh
mkdir stash2
ln -s /path/to/your/MulleBase64            stash2/MulleBase64
ln -s /path/to/your/mulle-core              stash2/mulle-core
ln -s /path/to/your/mulle-core-all-load     stash2/mulle-core-all-load
ln -s /path/to/your/MulleFoundation         stash2/MulleFoundation
ln -s /path/to/your/MulleFoundationBase     stash2/MulleFoundationBase
ln -s /path/to/your/MulleFoundation-startup stash2/MulleFoundation-startup
ln -s /path/to/your/MulleObjC               stash2/MulleObjC
ln -s /path/to/your/mulle-objc-list         stash2/mulle-objc-list
ln -s /path/to/your/mulle-objc-runtime      stash2/mulle-objc-runtime
```

## Configure, build, run

Point CMake at `stash2` with `-DSTASH_DIR=stash2`:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang -DSTASH_DIR=stash2
cmake --build build --parallel
./build/cmake-git-only-example
```

`STASH_DIR` is a CMake cache variable, so once set it sticks for that build
directory; you don't need to repeat `-DSTASH_DIR=stash2` on later
`cmake --build` calls. Use a separate build directory (e.g. `build-stash2`)
if you want to keep a `stash/`-based build around at the same time.

Omit `-DSTASH_DIR` (or pass `-DSTASH_DIR=stash`) to build against the
committed submodules instead.
