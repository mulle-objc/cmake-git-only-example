#
# Non-transitive consumer.
#
#   cmake -S nontransitive -B build -DCMAKE_BUILD_TYPE=Release \
#         -DCMAKE_C_COMPILER=mulle-clang
#
# This directory is a complete cmake project. The dependency checkouts live in
# the sibling ../stash (override with -DSTASH_DIR=...); see NOTE.md.
#
# All three MULLE_TRANSITIVE_* switches are off, so the libraries re-export
# nothing: every library is named here, with the WHOLE_ARCHIVE wrappers written
# out. This is the same program built the long way round; the transitive
# project next door is the normal, shorter contract.
#


cmake_minimum_required( VERSION 3.24...99.99)

# The project and its executable are named after the repository directory,
# which is the parent of this one.
get_filename_component( PROJECT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." REALPATH)
get_filename_component( PROJECT_NAME "${PROJECT_DIR}" NAME)
project( "${PROJECT_NAME}" VERSION 0.1.0 LANGUAGES C)


# The dependency checkouts, shared by both consumer projects.
set( STASH_DIR "stash" CACHE STRING "directory holding the dependency checkouts")
get_filename_component( STASH "${PROJECT_DIR}/${STASH_DIR}" REALPATH)


# The MULLE_TRANSITIVE_* switches below have to be set before the
# add_subdirectory() calls, because each dependency reads them while it
# configures itself. All three off is non-transitive.
set( MULLE_TRANSITIVE_LINK_LIBRARIES OFF)
set( MULLE_TRANSITIVE_SOURCE_INCLUDE   OFF)
set( MULLE_TRANSITIVE_LINKER_FLAGS     OFF)


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


# Dependencies. A dependency's headers come from one of two roots:
#
#  * an amalgamated library - mulle-core, mulle-core-all-load - keeps its
#    constituents' headers separate for the user, so
#    <mulle-sprintf/mulle-sprintf.h> resolves even though mulle-sprintf is
#    compiled into libmulle-core.a. It hands out its own src/ directory, and
#    the consumer adds that root.
#  * a regular library - MulleObjC, mulle-objc-runtime - copies its headers
#    into ${CMAKE_BINARY_DIR}/include, an installed-looking tree the consumer
#    adds once for all of them.
#
# Those roots belong here and not inside the libraries: a library's own sources
# need their dependencies' headers, and an INTERFACE include directory never
# reaches a library's own sources. So each root is declared *after* the
# add_subdirectory() that owns it - include_directories() is snapshotted into
# every target created from that point on, and add_subdirectory() is processed
# immediately.
#
# SYSTEM keeps warnings from dependency headers out of our build output.
add_subdirectory( "${STASH}/mulle-core" "${CMAKE_BINARY_DIR}/mulle-core")
include_directories( SYSTEM "${STASH}/mulle-core/src")

add_subdirectory( "${STASH}/mulle-core-all-load" "${CMAKE_BINARY_DIR}/mulle-core-all-load")
include_directories( SYSTEM "${STASH}/mulle-core-all-load/src")

add_subdirectory( "${STASH}/mulle-objc-runtime" "${CMAKE_BINARY_DIR}/mulle-objc-runtime")

# MulleObjC is the first layer that includes a flattened library (the runtime),
# so the shared root is needed from here on.
include_directories( SYSTEM "${CMAKE_BINARY_DIR}/include")

add_subdirectory( "${STASH}/MulleObjC" "${CMAKE_BINARY_DIR}/MulleObjC")


# Executable, named after the repository directory.
set( CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")

set( EXECUTABLE_NAME "${PROJECT_NAME}")
add_executable( "${EXECUTABLE_NAME}" "${PROJECT_DIR}/src/main.m")


# WHOLE_ARCHIVE is needed for all libraries with Objective-C classes, for
# <name>-startup libraries and for <name>-all-load libraries.
#
# Every library whose headers are included has to end up on this list: the order
# in which a dependency's staged headers reach
# ${CMAKE_BINARY_DIR}/include follows the link. Ninja hangs
# cmake_object_order_depends_target_<exe> on the object and fills it from the
# linked libraries, the Makefiles generator orders whole targets in
# CMakeFiles/Makefile2 (CMakeFiles/<exe>.dir/all: <lib>.dir/all). A dependency
# that is included but not linked would race - research/cmake-order-demo/ is the
# minimal repro of that case.
target_link_libraries( "${EXECUTABLE_NAME}"
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,MulleObjC>"
   mulle-objc-runtime
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,mulle-core-all-load>"
   mulle-core
)

# libm is a separate library on Linux and other non-Apple Unix systems. The
# transitive consumer gets it re-exported by MulleObjC; here the libraries are
# named individually, so it has to be added by hand. On Apple platforms the
# math symbols are provided by the system; Windows has no POSIX libm target.
if( UNIX AND NOT APPLE)
   target_link_libraries( "${EXECUTABLE_NAME}" m)
endif()


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
