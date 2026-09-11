cmake_minimum_required( VERSION 3.24...99.99)

# Determine name of Project and Executable from the name of the directory
get_filename_component( PROJECT_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
project( "${PROJECT_NAME}" VERSION 0.1.0 LANGUAGES C)


set( STASH_DIR "stash" CACHE STRING  "the place to store dependencies/submodules")


# Objective-C flags for everybody copied from mulle's CompilerFlagsObjC.cmake
# so they stay consistent with how the subprojects compile (notably -fobjc-tao,
# whose object-header layout must match the runtime we link against).
# The same OBJC_TAO_DEBUG_DISABLED policy was declared above, before the
# subprojects. Keep everybody on that exact policy.
#
string( TOUPPER "${CMAKE_BUILD_TYPE}" TMP_CONFIGURATION_NAME)
if( TMP_CONFIGURATION_NAME STREQUAL "DEBUG")
   if( NOT OBJC_TAO_DEBUG_DISABLED)
      add_definitions( "-fobjc-tao")
   endif()
else()
   add_definitions( "-DNS_BLOCK_ASSERTIONS")
endif()

# -------------------------------------------------------------------------
#                              Dependencies
# -------------------------------------------------------------------------

###
### MulleFoundation (edits here are rare)
###

# This cache policy is read by every mulle Objective-C subproject's
# CompilerFlagsObjC.cmake. Set it before add_subdirectory so MulleFoundation,
# MulleBase64, and the other dependencies compile with the same TAO setting as
# main.m; it remains overrideable with -D on the command line.
option( OBJC_TAO_DEBUG_DISABLED
        "Disable Objective-C TAO for debug builds"
        OFF)

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

# Nested add_subdirectory() projects must not each create the same IDE helper
# targets (mulle_sde_reflect, mulle_sde_clean_all, and friends).
set( IDE_SUPPORT OFF CACHE BOOL "Disable mulle-sde IDE helper targets")

# An amalgamated library is a collection of constituent libraries, whose
# headers still appear independent to the user. E.g. mulle-sprintf is contained
# in libmulle-core.a but you can use
# #include <mulle-sprintf/mulle-sprintf.h> as well as
# #include <mulle-core/mulle-core.h>.
#
# MulleFoundation headers treated like a secondary system include
# prefix (think /usr/local/include). SYSTEM is used so warnings in these
# headers are suppressed.
#
# MulleObjC headers and all others non-amalgamated mulle-objc library headers
# will be served from$ {CMAKE_BINARY_DIR}/include. Where a flattened form of
# the headers are copied to do their cmake/share/CMakeIncludeHeader.cmake.
#
include_directories( SYSTEM
   "${CMAKE_BINARY_DIR}/include"
   "${STASH_DIR}/mulle-core/src"
   "${STASH_DIR}/mulle-core-all-load/src"
   "${STASH_DIR}/MulleFoundationBase/src"
   "${STASH_DIR}/MulleFoundation/src"
)


#
# The libraries to be build and linked
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

# -------------------------------------------------------------------------
#                              Project
# -------------------------------------------------------------------------

###
### Additional Objective-C libraries
###

add_subdirectory( "${STASH_DIR}/MulleBase64")

###
### Executable
###
set( EXECUTABLE_NAME "${PROJECT_NAME}")

add_executable( "${EXECUTABLE_NAME}" src/main.m)


#
# WHOLE_ARCHIVE is needed for all libraries with Objective-C classes,
# <name>-startup libraries and <name>-all-load libraries
#
target_link_libraries( "${EXECUTABLE_NAME}"
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
   target_link_libraries( "${EXECUTABLE_NAME}" m)
endif()


# Keep the registration/init symbols visible for the runtime's dynamic lookup
# (stacktrace symbolication, loadinfo). Mirrors mulle-sde's ExecutableObjC.cmake
# so it works cross-platform. SHELL:LINKER: is CMake's portable way to pass a
# linker flag regardless of the compiler driver.
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

