#
# FetchContent consumer.
#
#   cmake -S . -B kitchen -DCMAKE_BUILD_TYPE=Release \
#         -DCMAKE_C_COMPILER=mulle-clang
#
# cmake clones the dependencies from GitHub at configure time with
# FetchContent and keeps them in the stash/ directory next to this file. There
# is no .gitmodules and no recorded commit: GIT_TAG master means master. The
# cost is that a build needs network access. Delete stash/ (or configure
# --fresh) to move to a newer master.
#


cmake_minimum_required( VERSION 3.30...99.99)

# The project and its executable are named after the repository directory,
# which is this one.
get_filename_component( PROJECT_DIR "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
get_filename_component( PROJECT_NAME "${PROJECT_DIR}" NAME)
project( "${PROJECT_NAME}" VERSION 0.1.0 LANGUAGES C)


# Keep the fetched sources in stash/ at the repository root, independent of
# the build directory. This has to be set before include( FetchContent), which
# declares the same cache variable. -DFETCHCONTENT_SOURCE_DIR_<NAME>=<dir>
# overrides a clone with a local checkout.
set( FETCHCONTENT_BASE_DIR "${PROJECT_DIR}/stash" CACHE PATH "where FetchContent stores dependency checkouts")

include( FetchContent)

set( DEPENDENCY_TAG "master" CACHE STRING "branch or tag to fetch the dependencies from")


# The MULLE_TRANSITIVE_* switches below have to be set before the dependency
# add_subdirectory() calls (FetchContent makes those), because each dependency
# reads them while it configures itself. All three on is transitive.
set( MULLE_TRANSITIVE_LINK_LIBRARIES ON)
set( MULLE_TRANSITIVE_SOURCE_INCLUDE   ON)
set( MULLE_TRANSITIVE_LINKER_FLAGS     ON)


# Compiler settings. Dependencies and this project compile with the same flags,
# taken from mulle's CompilerFlagsObjC.cmake. -fobjc-tao changes the
# object-header layout and must match the runtime we link against.
option( OBJC_TAO_DEBUG_DISABLED
        "Disable Objective-C TAO for debug builds"
        OFF)

string( TOUPPER "${CMAKE_BUILD_TYPE}" TMP_CONFIGURATION_NAME)
if( TMP_CONFIGURATION_NAME STREQUAL "DEBUG")
   if( NOT OBJC_TAO_DEBUG_DISABLED)
      add_definitions( "-fobjc-tao")
   endif()
else()
   add_definitions( "-DNS_BLOCK_ASSERTIONS")
endif()

# Switches the mulle projects would otherwise take from the cmake command line.
# Cache variables, so -D can still override them.
set( MULLE_OBJC_DEBUG_SUPPORT OFF CACHE BOOL "mulle-objc debug support")
set( CREATE_OBJC_DEPS_INC     OFF CACHE BOOL "create objc-deps.inc")

# Nested add_subdirectory() projects must not each create the same IDE helper
# targets (mulle_sde_reflect, mulle_sde_clean_all, and friends).
set( IDE_SUPPORT OFF CACHE BOOL "Disable mulle-sde IDE helper targets")


# Dependencies, in dependency order. FetchContent_MakeAvailable() clones (or
# reuses) the source under stash/ and calls add_subdirectory() on it, so each
# root is again declared directly after the dependency that owns it.
FetchContent_Declare( mulle-core
   GIT_REPOSITORY https://github.com/mulle-core/mulle-core.git
   GIT_TAG        "${DEPENDENCY_TAG}")
FetchContent_MakeAvailable( mulle-core)
include_directories( SYSTEM "${mulle-core_SOURCE_DIR}/src")

FetchContent_Declare( mulle-core-all-load
   GIT_REPOSITORY https://github.com/mulle-core/mulle-core-all-load.git
   GIT_TAG        "${DEPENDENCY_TAG}")
FetchContent_MakeAvailable( mulle-core-all-load)
include_directories( SYSTEM "${mulle-core-all-load_SOURCE_DIR}/src")

FetchContent_Declare( mulle-objc-runtime
   GIT_REPOSITORY https://github.com/mulle-objc/mulle-objc-runtime.git
   GIT_TAG        "${DEPENDENCY_TAG}")
FetchContent_MakeAvailable( mulle-objc-runtime)

# MulleObjC is the first layer that includes a flattened library (the runtime),
# so the shared root is needed from here on.
include_directories( SYSTEM "${CMAKE_BINARY_DIR}/include")

FetchContent_Declare( MulleObjC
   GIT_REPOSITORY https://github.com/mulle-objc/MulleObjC.git
   GIT_TAG        "${DEPENDENCY_TAG}")
FetchContent_MakeAvailable( MulleObjC)

FetchContent_Declare( MulleFoundationBase
   GIT_REPOSITORY https://github.com/MulleFoundation/MulleFoundationBase.git
   GIT_TAG        "${DEPENDENCY_TAG}")
FetchContent_MakeAvailable( MulleFoundationBase)
include_directories( SYSTEM "${MulleFoundationBase_SOURCE_DIR}/src")

FetchContent_Declare( MulleFoundation
   GIT_REPOSITORY https://github.com/MulleFoundation/MulleFoundation.git
   GIT_TAG        "${DEPENDENCY_TAG}")
FetchContent_MakeAvailable( MulleFoundation)
include_directories( SYSTEM "${MulleFoundation_SOURCE_DIR}/src")

FetchContent_Declare( MulleFoundation-startup
   GIT_REPOSITORY https://github.com/MulleFoundation/MulleFoundation-startup.git
   GIT_TAG        "${DEPENDENCY_TAG}")
FetchContent_MakeAvailable( MulleFoundation-startup)

FetchContent_Declare( MulleBase64
   GIT_REPOSITORY https://github.com/MulleWeb/MulleBase64.git
   GIT_TAG        "${DEPENDENCY_TAG}")
FetchContent_MakeAvailable( MulleBase64)


# Executable, named after the repository directory.
set( CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")

set( EXECUTABLE_NAME "${PROJECT_NAME}")
add_executable( "${EXECUTABLE_NAME}" "${PROJECT_DIR}/src/main.m")


# Only what src/main.m uses directly; the rest arrives through the link.
target_link_libraries( "${EXECUTABLE_NAME}"
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,MulleBase64>"
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,MulleFoundation>"
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,MulleFoundation-startup>"
)

# No explicit libm here: the libraries re-export their system libraries
# (libm among them) to a transitive consumer.


# Keep the registration/init symbols visible for the runtime's dynamic lookup
# (stacktrace symbolication, loadinfo). SHELL:LINKER: is CMake's portable way
# to pass a linker flag regardless of the compiler driver.
if( WIN32)
   target_link_options( "${EXECUTABLE_NAME}" PRIVATE "SHELL:LINKER:--export-all-symbols")
elseif( APPLE)
   # Apple's ld exports specific symbols rather than everything.
   target_link_options( "${EXECUTABLE_NAME}" PRIVATE
      "SHELL:LINKER:-exported_symbol,___register_mulle_objc_universe"
      "SHELL:LINKER:-exported_symbol,_mulle_atinit"
      "SHELL:LINKER:-exported_symbol,_mulle_atexit"
   )
else() # other UNIX
   target_link_options( "${EXECUTABLE_NAME}" PRIVATE "SHELL:LINKER:--export-dynamic")
endif()
