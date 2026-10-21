# cmake-git-only-example

> Needs mulle-objc 0.31 or newer.
>
> A companion project to the
> [De Re mulle-objc](https://mulle-kybernetik.com/de-re-mulle-objc) Developer
> Guide.

#### 🧬 Build a MulleWebFoundation executable with `mulle-clang`, CMake and Git

The necessary ingredients are:

| Tool | Version |
|---|---|
| [Git](https://git-scm.com/) | any recent version |
| [CMake](https://cmake.org/) | 3.30 or newer |
| [mulle-clang](https://github.com/mulle-cc/mulle-clang-project) | a current release |
| curl, expat and zlib development files | system packages |

The clone directory names the project and the executable. You
choose the [Class Library](#class-library) with the `-b` branch.

```sh
git clone -b MulleWebFoundation https://github.com/mulle-objc/cmake-git-only-example.git hello
cd hello

cmake -S . -B kitchen \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER=mulle-clang
cmake --build kitchen --parallel
./kitchen/hello
```

It prints:

```text
VfL Bochum 1848
VmZMIEJvY2h1bSAxODQ4
```

For a debug build use its own directory:

```sh
cmake -S . -B kitchen-debug -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=mulle-clang
cmake --build kitchen-debug --parallel
./kitchen-debug/hello
```


## Class Library

| Branch | What it builds |
|---|---|
| `MulleFoundation` | the full Foundation, plus the `MulleBase64` example (default) |
| `MulleObjC` | only `MulleObjC`, its startup shim and the runtime |
| `MulleWebFoundation` | Foundation plus the `MulleWeb` client stack |

All three share the same layout and build commands.

## Layout

```text
CMakeLists.txt   the whole build
src/main.m       the program
stash/           FetchContent checkouts (generated)
kitchen/         build directory (generated)
```

`CMakeLists.txt` fetches, in order:

* `mulle-core` / `mulle-core-all-load` — C infrastructure
* `mulle-objc-runtime` — the Objective-C runtime
* `MulleObjC` — language support
* `MulleFoundationBase` / `MulleFoundation` / `MulleFoundation-startup` — Foundation and startup glue
* `MulleWebFoundation` — the web client stack, including its amalgamated `MulleBase64`

The executable links only what `src/main.m` uses directly: `MulleWebFoundation`
and `MulleFoundation-startup`. The rest arrives through the link because the
libraries re-export their dependencies. `WHOLE_ARCHIVE` keeps the Objective-C
classes and the startup/all-load code in the program.

`MulleWebFoundation` is a static amalgamation, so its curl/expat/zlib
file-path dependencies do not propagate through the link interface. The
executable links `curl`, `EXPAT::EXPAT` and `ZLIB::ZLIB` explicitly. curl is
named without `find_package()` so the linker can choose the shared library.

`FETCHCONTENT_BASE_DIR` is set before `include( FetchContent)`, which is what
puts the clones in `stash/` instead of `kitchen/_deps`. Deleting `kitchen/`
keeps the sources; deleting `stash/` fetches fresh revisions.

```sh
# pin every dependency
cmake -S . -B kitchen -DDEPENDENCY_TAG=0.30.0 \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang

# use one checkout of your own
cmake -S . -B kitchen -DFETCHCONTENT_SOURCE_DIR_MULLE-CORE=/path/to/mulle-core \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang
```

## 🩼 When the build falls over

* **CMake is too old** — this project needs 3.30. Check `cmake --version`, then
  update cmake or use a newer one from your package manager.
* **`curl/curl.h`, `expat.h` or `zlib.h` not found** — install the development
  packages (on Debian/Ubuntu: `libcurl4-openssl-dev libexpat1-dev zlib1g-dev`).
* **Dependencies are stale** — `rm -rf kitchen stash` and configure again.
* **A fetched checkout is in the way** — delete just that directory from
  `stash/`, or point `FETCHCONTENT_SOURCE_DIR_<NAME>` at your own checkout.
* **Undefined curl, expat or zlib symbols** — the system libraries are missing
  from the executable link; see the `target_link_libraries()` block.
* **Header not found** — make sure you did not manually add a second include
  root for a dependency; the interleaved `include_directories()` calls in
  `CMakeLists.txt` are deliberate.

## More

* [De Re mulle-objc — Organizing a Project](https://mulle-kybernetik.com/de-re-mulle-objc/project.html)
  — the long-form walkthrough of this `CMakeLists.txt`
