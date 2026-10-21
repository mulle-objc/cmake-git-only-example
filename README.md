# cmake-git-only-example

> This project needs mulle-objc 0.31 minimum
>
> This is a companion project to the
> [De Re mulle-objc](https://mulle-kybernetik.com/de-re-mulle-objc)
> Developer Guide.

#### 🧬 Build a MulleObjC executable with `mulle-clang`, CMake and Git

This branch is the stripped-down companion to the MulleFoundation example: it
removes the Foundation layers (`MulleFoundationBase`, `MulleFoundation` and
`MulleFoundation-startup`) and the `MulleBase64` category, and builds only
[MulleObjC](https://github.com/mulle-objc/MulleObjC) and the runtime beneath it.

Three tools, zero magic: clone this repo, point CMake at `mulle-clang`, and
`add_subdirectory()` does the rest.

No [mulle-sde](https://github.com/mulle-sde/mulle-sde),
no prebuilt SDK, no package manager — just [Git](https://git-scm.com/),
[CMake](https://cmake.org/) and [mulle-clang](https://github.com/mulle-cc/mulle-clang-project)
turning an Objective-C source file into a running MulleObjC executable.

By default the dependencies are fetched by CMake with `FetchContent`, straight
from their Git repositories. The `transitive/` and `nontransitive/` variants
instead use plain Git submodules (see [`.gitmodules`](.gitmodules)). Either way
they are built from source alongside your own code.

The project and executable take their name from the directory you clone into, so
rename the clone to rename your program.

[![CI](https://github.com/MulleFoundation/cmake-git-only-example/actions/workflows/ci.yml/badge.svg)](https://github.com/MulleFoundation/cmake-git-only-example/actions/workflows/ci.yml)

## What it builds

`src/main.m` defines a `Greeter` class, creates one instance in an autorelease
pool and sends it a message:

```objc
#import <MulleObjC/MulleObjC.h>

@interface Greeter : NSObject
{
   char   *_name;
}

- (id) initWithName:(char *) name;
- (void) greet;

@end
```

The program prints:

```text
Hello, VfL Bochum 1848
```

## Requirements

| Requirement | Version | Purpose |
|---|---:|---|
| [Git](https://git-scm.com/) | any recent version | Clone the repo and its dependencies |
| [CMake](https://cmake.org/) | 3.24 or newer | Configure and build |
| [mulle-clang](https://github.com/mulle-cc/mulle-clang-project) | a current release | Compile the Objective-C and C sources |

Commands below target a Unix-like shell. CI currently validates Ubuntu and
macOS.

## Get the source

The `MulleObjC` branch is not the repository's default branch, so switch to it
after cloning:

```sh
git clone https://github.com/MulleFoundation/cmake-git-only-example.git
cd cmake-git-only-example
git switch MulleObjC
```

That is all the default (FetchContent) project needs — cmake clones the
dependencies itself.

The `transitive/` and `nontransitive/` variants use git submodules instead;
fetch them with:

```sh
git submodule update --init --recursive --remote
```

The submodules track `master` (`branch = master` in `.gitmodules`), so
`--remote` checks out the current tip of each dependency. A plain
`git clone --recurse-submodules` would instead give you the commit recorded in
the repository. Update them later with the same command.

## Build

Three self-contained projects, sharing the code in `src/`. Point cmake at the
one you want:

```sh
# FetchContent: cmake clones the dependencies at configure time (recommended)
cmake -S . -B build \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang
cmake --build build --parallel
./build/cmake-git-only-example

# git submodules: the libraries re-export what they depend on
cmake -S transitive -B build-transitive \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang
cmake --build build-transitive --parallel
./build-transitive/cmake-git-only-example

# git submodules, nothing re-exported: the project names every library itself
cmake -S nontransitive -B build-nontransitive \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang
cmake --build build-nontransitive --parallel
./build-nontransitive/cmake-git-only-example
```

All three print the same line, `Hello, VfL Bochum 1848`.

A Debug build is the same with a separate build directory:

```sh
cmake -S . -B build-debug -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=mulle-clang
cmake --build build-debug --parallel
./build-debug/cmake-git-only-example
```

There is no install step; delete the build directory for a clean configure.
Build outputs are Git-ignored.

## The three consumers

* [`CMakeLists.txt`](CMakeLists.txt) is the recommended project and the default
  one (`cmake -S .`). It uses the transitive link (below), and hands the dependency
  checkout to `FetchContent`: each dependency is cloned from GitHub at configure
  time, tracking `master` (`-DDEPENDENCY_TAG=` picks another branch or tag).
  Point `-DFETCHCONTENT_SOURCE_DIR_<NAME>=<dir>` at a local checkout to build
  against one you are editing.
* [`transitive/CMakeLists.txt`](transitive/CMakeLists.txt) is the same transitive
  link with plain git submodules. It names only the library `src/main.m` uses
  directly, `MulleObjC`; `mulle-objc-runtime`, `mulle-core` and
  `mulle-core-all-load` arrive through the link, because each library re-exports
  what it depends on. The all-load library keeps its `WHOLE_ARCHIVE` semantics.
* [`nontransitive/CMakeLists.txt`](nontransitive/CMakeLists.txt) turns the
  `MULLE_TRANSITIVE_*` switches off, names all four libraries and writes the
  `WHOLE_ARCHIVE` wrappers out itself.

Each project sets its own switches, so a build directory cannot end up with a
mixture of the shapes.

## How the build is wired

Each project's [`CMakeLists.txt`](CMakeLists.txt) adds the dependencies in order
and links the executable (named after the repository directory) against them:

* `mulle-core` / `mulle-core-all-load` — base C infrastructure
* `mulle-objc-runtime` / `MulleObjC` — the mulle-objc runtime and language support
* `mulle-objc-list` — command-line inspection tools; checked out with the
  submodules, but not built or linked by this project

Where a dependency's headers come from depends on the kind of library:

* an **amalgamated** library keeps its constituents' headers separate, so
  `#include <mulle-sprintf/mulle-sprintf.h>` still resolves even though
  `mulle-sprintf` is compiled into `libmulle-core.a`. It hands out its own
  `src/` directory.
* a **regular** library copies its headers into `${CMAKE_BINARY_DIR}/include`,
  an installed-looking tree that serves all of them at once.

The matching include roots are declared in the consumer file, following two
rules:

* they are declared here and not inside the libraries, because an `INTERFACE`
  include directory reaches a library's consumers and never its own sources —
  while a library's own sources need their dependencies' headers, too;
* each root is declared *after* the `add_subdirectory()` that owns it, so that
  library never compiles against its own headers through the global path, and
  everything above it (and the executable) does see the root.

`BASICS.md` has the rules in full, with the three shapes an `add_subdirectory()`
consumer can put a mulle library in.

## Setting up the submodules from scratch (maintainers)

Register each dependency individually with `git submodule add -b master`, from a
clean `stash/`:

```sh
git submodule add -b master https://github.com/mulle-core/mulle-core.git stash/mulle-core
git submodule add -b master https://github.com/mulle-core/mulle-core-all-load.git stash/mulle-core-all-load
git submodule add -b master https://github.com/mulle-objc/mulle-objc-runtime.git stash/mulle-objc-runtime
git submodule add -b master https://github.com/mulle-objc/MulleObjC.git stash/MulleObjC
git submodule add -b master https://github.com/mulle-objc/mulle-objc-list.git stash/mulle-objc-list
```

Verify with:

```sh
git status --short
git submodule status
```

Each `stash/<name>` should show as a single added gitlink, and each
dependency should list one commit SHA.

## Building against your own checkouts

To edit a dependency and rebuild against it immediately, point the build at
your working checkout instead of a fresh clone.

With the default project, override one dependency at a time:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang \
      -DFETCHCONTENT_SOURCE_DIR_MULLE-CORE=/path/to/your/mulle-core
```

With `transitive/` or `nontransitive/`, `STASH_DIR` names a directory of
checkouts next to the repository root. `stash2/` is the Git-ignored local one
(symlink each dependency into it, or point `-DSTASH_DIR=` anywhere):

```sh
cmake -S transitive -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=mulle-clang \
      -DSTASH_DIR=stash2
```

## Platform notes

* Linux and other non-Apple Unix: `--export-dynamic`; `libm` is re-exported to
  the transitive consumer and linked explicitly by the nontransitive one
* macOS: required symbols exported individually; math symbols come from the system
* Windows: exports all symbols needed by the runtime, no `libm` target;
  output is `cmake-git-only-example.exe`, possibly under `build/Release/` with
  a multi-config generator

CI currently validates Ubuntu and macOS; Windows is untested and depends on
`mulle-clang`/runtime/submodule availability there.

## More

* [`BASICS.md`](BASICS.md) — the three cmake shapes a mulle library must support
  and what an `add_subdirectory()` consumer has to know about its headers
* [`research/`](research/) — two minimal pure-cmake demos, each with its own
  README and measured result matrix
