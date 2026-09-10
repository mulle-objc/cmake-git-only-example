cmake_minimum_required( VERSION 3.24...99.99)

project( cmake-git-only-example VERSION 0.1.0 LANGUAGES C)


set( STASH_DIR "stash" CACHE STRING  "dependency/submodule")

###
### MulleFoundation
###

#
# Simulates a git-clone consumer: stash/ contains symlinks to the amalgamation
# and its C infrastructure, all built entirely from source via
# add_subdirectory(). There is no prebuilt SDK (no -DMULLE_SDK_PATH).
#

# Build knobs that would otherwise be passed on the cmake command line. Set
# before the add_subdirectory() calls so the mulle projects pick them up
# (each uses `if( NOT DEFINED ...)`), and as cache vars so they can still be
# overridden with -D on the command line.
set( MULLE_OBJC_DEBUG_SUPPORT OFF CACHE BOOL "mulle-objc debug support")
set( CREATE_OBJC_DEPS_INC     OFF CACHE BOOL "create objc-deps.inc")
set( MULLE_TRANSITIVE_LINK_LIBRARIES OFF CACHE BOOL
     "propagate dependency libraries through target interfaces")
set( MULLE_TRANSITIVE_SOURCE_INCLUDE OFF CACHE BOOL
     "Propagate source include directories to add_subdirectory consumers")
# This cache policy is read by every mulle Objective-C subproject's
# CompilerFlagsObjC.cmake. Set it before add_subdirectory so MulleFoundation,
# MulleBase64, and the other dependencies compile with the same TAO setting as
# main.m; it remains overrideable with -D on the command line.
option( OBJC_TAO_DEBUG_DISABLED
        "Disable Objective-C TAO for debug builds"
        OFF)
# Nested add_subdirectory() projects must not each create the same IDE helper
# targets (mulle_sde_reflect, mulle_sde_clean_all, and friends).
set( IDE_SUPPORT OFF CACHE BOOL "Disable mulle-sde IDE helper targets")


# Amalgamation-wide header roots, treated like a secondary system include prefix
# (think /usr/local/include): SYSTEM so warnings in these headers are suppressed,
# and directory-scoped (include_directories, not per-target) so every target
# defined below inherits them.
#
# The reorganized C libraries keep their <prefix>/ header dirs under src/, so
# one -I <lib>/src serves them directly:
#   stash/mulle-core/src          -> <mulle-core/...>, <mulle-c11/...>, ...
#   stash/mulle-core-all-load/src -> <mulle-core-all-load/...>, <mulle-stacktrace/...>
#
# MulleBase64 will be served from
# ${CMAKE_BINARY_DIR}/include here in a flattened form due to
# its cmake/share/CMakeIncludeHeader.cmake.
include_directories( SYSTEM
   "${CMAKE_BINARY_DIR}/include"
   "${STASH_DIR}/mulle-core/src"
   "${STASH_DIR}/mulle-core-all-load/src"
   "${STASH_DIR}/MulleFoundationBase/src"
   "${STASH_DIR}/MulleFoundation/src"
)

#
#   mulle-core          : base C infrastructure
#   mulle-core-all-load : _mulle_atinit / _mulle_atexit   (needs mulle-core)
#   mulle-objc-runtime  : the ObjC runtime                (needs mulle-core, and
#                         references mulle-core-all-load, so it comes last)
#
add_subdirectory( "${STASH_DIR}/mulle-core")
add_subdirectory( "${STASH_DIR}/mulle-core-all-load")
add_subdirectory( "${STASH_DIR}/mulle-objc-runtime")

# The runtime also builds tool executables we do not need; exclude just those.
foreach( _tool mulle-objc-uniqueid mulle-objc-signature
                _1_mulle-objc-uniqueid _1_mulle-objc-signature)
   if( TARGET "${_tool}")
      set_target_properties( "${_tool}" PROPERTIES EXCLUDE_FROM_ALL TRUE)
   endif()
endforeach()

add_subdirectory( "${STASH_DIR}/MulleObjC")
add_subdirectory( "${STASH_DIR}/MulleFoundationBase")
add_subdirectory( "${STASH_DIR}/MulleFoundation")
add_subdirectory( "${STASH_DIR}/MulleFoundation-startup")


###
### Additional Foundation directories
###

add_subdirectory( "${STASH_DIR}/MulleBase64")

###
### Executable
###


# Objective-C flags for main.m, copied from mulle's CompilerFlagsObjC.cmake so
# they stay consistent with how the subprojects compile (notably -fobjc-tao,
# whose object-header layout must match the runtime we link against).
# The same OBJC_TAO_DEBUG_DISABLED policy was declared above, before the
# subprojects. Keep main.m on that exact policy.
string( TOUPPER "${CMAKE_BUILD_TYPE}" TMP_CONFIGURATION_NAME)
if( TMP_CONFIGURATION_NAME STREQUAL "DEBUG")
   if( NOT OBJC_TAO_DEBUG_DISABLED)
      add_definitions( "-fobjc-tao")
   endif()
else()
   add_definitions( "-DNS_BLOCK_ASSERTIONS")
endif()

add_executable( mulle-objc-executable src/main.m)

#
# WHOLE_ARCHIVE is needed for all libraries with Objective-C classes,
# <name>-startup libraries and <name>-all-load libraries
#
target_link_libraries( mulle-objc-executable
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,MulleBase64>"
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,MulleFoundation>"
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,MulleFoundationBase>"
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,MulleFoundation-startup>"
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,MulleObjC>"
   mulle-objc-runtime
   "$<LINK_LIBRARY:WHOLE_ARCHIVE,mulle-core-all-load>"
   mulle-core
)

# libm is a separate library on Linux and other non-Apple Unix systems. On
# Apple platforms the math symbols are provided by the system; Windows has no
# POSIX libm target.
if( UNIX AND NOT APPLE)
   target_link_libraries( mulle-objc-executable m)
endif()


# Keep the registration/init symbols visible for the runtime's dynamic lookup
# (stacktrace symbolication, loadinfo). Mirrors mulle-sde's ExecutableObjC.cmake
# so it works cross-platform. SHELL:LINKER: is CMake's portable way to pass a
# linker flag regardless of the compiler driver.
if( WIN32)
   target_link_options( mulle-objc-executable PRIVATE "SHELL:LINKER:--export-all-symbols")
elseif( APPLE)
   # Apple's ld exports specific symbols rather than everything.
   target_link_options( mulle-objc-executable PRIVATE
      "SHELL:LINKER:-exported_symbol,___register_mulle_objc_universe"
      "SHELL:LINKER:-exported_symbol,_mulle_atinit"
      "SHELL:LINKER:-exported_symbol,_mulle_atexit"
   )
else() # other UNIX
   target_link_options( mulle-objc-executable PRIVATE "SHELL:LINKER:--export-dynamic")
endif()

