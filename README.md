# cmake-git-only-example

> This project needs mulle-objc 0.31 minimum
>
> This is a companion project to the
> [De Re mulle-objc](https://mulle-kybernetik.com/de-re-mulle-objc)
> Developer Guide.

#### 🧬 Build a MulleWebFoundation executable with `mulle-clang`, CMake and Git

This branch adds `MulleWebFoundation` on top of the MulleFoundation example:
the full Foundation plus the web client stack (curl, expat, zlib, OpenSSL and
the `MulleWeb` libraries). The `MulleObjC` branch is the stripped-down sibling
that builds against `MulleObjC` alone.

Three tools, zero magic: clone this repo, point CMake at `mulle-clang`, and
`FetchContent` does the rest.

No [mulle-sde](https://github.com/mulle-sde/mulle-sde),
no prebuilt SDK, no package manager and no git submodules — just
[Git](https://git-scm.com/), [CMake](https://cmake.org/) and
[mulle-clang](https://github.com/mulle-cc/mulle-clang-project) turning an
Objective-C source file into a running
[MulleWebFoundation](https://github.com/MulleWeb/MulleWebFoundation)
executable.

CMake fetches the dependencies straight from their Git repositories at
configure time and keeps them in `stash/`. `kitchen/` is the build directory.
Both are Git-ignored.

The project and executable take their name from the directory you clone into, so
rename the clone to rename your program.

[![CI](https://github.com/mulle-objc/cmake-git-only-example/actions/workflows/ci.yml/badge.svg)](https://github.com/mulle-objc/cmake-git-only-example/actions/workflows/ci.yml)

## What it builds

`src/main.m` prints `VfL Bochum 1848`, then uses the `MulleBase64` category that
`MulleWebFoundation` amalgamates on `NSData` to print its Base64 encoding:

```text
VfL Bochum 1848
VmZMIEJvY2h1bSAxODQ4
```

## Requirements

| Requirement | Version | Purpose |
|---|---:|---|
| [Git](https://git-scm.com/) | any recent version | Clone the repo and its dependencies |
| [CMake](https://cmake.org/) | 3.30 or newer | Configure and build |
| [mulle-clang](https://github.com/mulle-cc/mulle-clang-project) | a current release | Compile the Objective-C and C sources |
| curl, expat, zlib and OpenSSL development files | system packages | C libraries used by MulleWebFoundation |

Commands below target a Unix-like shell. CI currently validates Ubuntu and
macOS.

## Get the source

The `MulleWebFoundation` branch is not the repository's default branch, so
switch to it after cloning:

```sh
git clone https://github.com/mulle-objc/cmake-git-only-example.git
cd cmake-git-only-example
git switch MulleWebFoundation
```

There is no submodule step: the first configure fetches everything into
`stash/`.

## Build

`kitchen/` is the build directory, kept out of the source tree:

```sh
cmake -S . -B kitchen \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang
cmake --build kitchen --parallel
./kitchen/cmake-git-only-example
```

It prints `VfL Bochum 1848` and its Base64 encoding.

A Debug build is the same with its own build directory:

```sh
cmake -S . -B kitchen-debug -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=mulle-clang
cmake --build kitchen-debug --parallel
./kitchen-debug/cmake-git-only-example
```

There is no install step. Delete `kitchen/` for a clean build; delete both
`kitchen/` and `stash/` to configure from scratch and fetch fresh dependencies.

## How the build is wired

[`CMakeLists.txt`](CMakeLists.txt) adds the dependencies in order and links the
executable (named after the repository directory) against them:

* `mulle-core` / `mulle-core-all-load` — base C infrastructure
* `mulle-objc-runtime` / `MulleObjC` — the mulle-objc runtime and language support
* `MulleFoundationBase` / `MulleFoundation` / `MulleFoundation-startup` — Foundation classes and startup code
* `MulleWebFoundation` — the web client stack (and its amalgamated `MulleBase64`)

`FetchContent` keeps the clones in `stash/` (`FETCHCONTENT_BASE_DIR`) instead of
the build directory, so several build directories share one checkout.
`DEPENDENCY_TAG` chooses the revision and defaults to `master`.

A dependency's headers come from one of two roots:

* an **amalgamated** library (`mulle-core`, `mulle-core-all-load`,
  `MulleFoundationBase`, `MulleFoundation`, `MulleWebFoundation`) keeps its
  constituents' headers separate, so `#include <mulle-sprintf/mulle-sprintf.h>`
  still resolves even though `mulle-sprintf` is compiled into
  `libmulle-core.a`. It hands out its own `src/` directory.
* a **regular** library (`MulleObjC`, `mulle-objc-runtime`,
  `MulleFoundation-startup`) copies its headers into
  `${CMAKE_BINARY_DIR}/include`, an installed-looking tree that serves all of
  them at once.

The include roots are declared after the dependency that owns them, so a library
never compiles against its own headers through the global path, while everything
above it — and the executable — does see the root. `SYSTEM` keeps dependency
warnings out of the build output.

The executable names only the libraries `src/main.m` uses directly:
`MulleWebFoundation` and `MulleFoundation-startup`. MulleFoundation and the
libraries below it arrive through the link because each library re-exports what
it depends on. `WHOLE_ARCHIVE` keeps the Objective-C classes and the
startup/all-load glue in the program.

`MulleWebFoundation` is a static amalgamation, so its curl/expat/zlib
file-path dependencies do not propagate through the link interface. The
executable links `curl`, `EXPAT::EXPAT` and `ZLIB::ZLIB` explicitly. curl is
named without `find_package()` so the linker can choose the shared library
instead of pulling in all of static `libcurl.a`'s dependencies.

## Pinning a dependency or using your own checkout

Pin all dependencies to a tag or branch with:

```sh
cmake -S . -B kitchen -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang \
      -DDEPENDENCY_TAG=0.30.0
```

To build against a checkout you are editing, override just that dependency:

```sh
cmake -S . -B kitchen -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang \
      -DFETCHCONTENT_SOURCE_DIR_MULLE-CORE=/path/to/your/mulle-core
```

FetchContent caches the clones in `stash/`, so a later configure does not
download again. Delete `stash/` (or configure with `--fresh`) to move to a newer
`master`.

## Platform notes

* Linux and other non-Apple Unix: `--export-dynamic`; `libm` is re-exported by
  the libraries
* macOS: required symbols exported individually; math symbols come from the system
* Windows: exports all symbols needed by the runtime, no `libm` target;
  output is `cmake-git-only-example.exe`, possibly under `kitchen/Release/` with
  a multi-config generator

CI currently validates Ubuntu and macOS; Windows is untested and depends on
`mulle-clang`/runtime availability there.

## More

* [De Re mulle-objc — Organizing a Project](https://mulle-kybernetik.com/de-re-mulle-objc/project.html)
  — the long-form explanation of this `CMakeLists.txt`
