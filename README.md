# cmake-git-only-example

#### Build a MulleFoundation executable with `mulle-clang`, CMake and Git

A minimal example of building an Objective-C executable against
[MulleFoundation](https://github.com/MulleFoundation/MulleFoundation) using
only [Git](https://git-scm.com/), [CMake](https://cmake.org/) and
[mulle-clang](https://github.com/mulle-cc/mulle-clang-project) — no
[mulle-sde](https://github.com/mulle-sde/mulle-sde), no pre-built SDK.

Dependencies are Git submodules (see [`.gitmodules`](.gitmodules)) built from
source via CMake's `add_subdirectory()`.

[![CI](https://github.com/MulleFoundation/cmake-git-only-example/actions/workflows/ci.yml/badge.svg)](https://github.com/MulleFoundation/cmake-git-only-example/actions/workflows/ci.yml)

## What it builds

`src/main.m` prints `VfL Bochum 1848`, then uses the MulleBase64 category on
`NSData` to print its Base64 encoding:

```text
VfL Bochum 1848
VmZMIEJvY2h1bSAxODQ4
```

## Requirements

| Requirement | Version | Purpose |
|---|---:|---|
| [Git](https://git-scm.com/) | any recent version | Clone the repo and its submodules |
| [CMake](https://cmake.org/) | 3.24 or newer | Configure and build |
| [mulle-clang](https://github.com/mulle-cc/mulle-clang-project) | a current release | Compile the Objective-C and C sources |

Commands below target a Unix-like shell. CI currently validates Ubuntu and
macOS.

## Get the source

```sh
git clone --recurse-submodules https://github.com/MulleFoundation/cmake-git-only-example.git
cd cmake-git-only-example
```

If cloned without `--recurse-submodules`:

```sh
git submodule update --init --recursive
```

Submodules land under `stash/` as ordinary Git checkouts.

### Setting up the submodules from scratch (maintainers)

`stash/` must not be added as one plain directory — that stages every
dependency file instead of a submodule gitlink. Each dependency is registered
individually, from a clean `stash/`:

```sh
git submodule add https://github.com/MulleWeb/MulleBase64.git stash/MulleBase64
git submodule add https://github.com/mulle-core/mulle-core.git stash/mulle-core
git submodule add https://github.com/mulle-core/mulle-core-all-load.git stash/mulle-core-all-load
git submodule add https://github.com/MulleFoundation/MulleFoundation.git stash/MulleFoundation
git submodule add https://github.com/MulleFoundation/MulleFoundationBase.git stash/MulleFoundationBase
git submodule add https://github.com/MulleFoundation/MulleFoundation-startup.git stash/MulleFoundation-startup
git submodule add https://github.com/mulle-objc/MulleObjC.git stash/MulleObjC
git submodule add https://github.com/mulle-objc/mulle-objc-list.git stash/mulle-objc-list
git submodule add https://github.com/mulle-objc/mulle-objc-runtime.git stash/mulle-objc-runtime
```

Verify with:

```sh
git status --short
git submodule status
```

Each `stash/<name>` should show as a single added gitlink, and each
dependency should list one commit SHA.

## Build

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang
cmake --build build --parallel
./build/mulle-objc-executable
```

For a Debug build, use a separate build directory:

```sh
cmake -S . -B build-debug -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=mulle-clang
cmake --build build-debug --parallel
./build-debug/mulle-objc-executable
```

There is no install step; delete `build/`/`build-debug/` for a clean
configure. Build outputs are Git-ignored.

## How the build is wired

The top-level [`CMakeLists.txt`](CMakeLists.txt) adds the dependencies in
order and links `mulle-objc-executable` against them:

* `mulle-core` / `mulle-core-all-load` — base C infrastructure
* `mulle-objc-runtime` / `MulleObjC` — the mulle-objc runtime and language support
* `MulleFoundationBase` / `MulleFoundation` / `MulleFoundation-startup` — Foundation classes and startup code
* `MulleBase64` — the Base64 category used by `src/main.m`

Everything is assembled by Git, CMake and the compiler — no `mulle-sde`, no
pre-installed SDK.

## Platform notes

* Linux and other non-Apple Unix: `--export-dynamic` plus a separate `libm` link
* macOS: required symbols exported individually; math symbols come from the system
* Windows: exports all symbols needed by the runtime, no `libm` target;
  output is `mulle-objc-executable.exe`, possibly under `build/Release/` with
  a multi-config generator

CI currently validates Ubuntu and macOS; Windows is untested and depends on
`mulle-clang`/runtime/submodule availability there.

