
add_library (common STATIC
    misc.c
    symbols.c
    pehelp.c
)
target_link_libraries (common LINK_PRIVATE
    psapi
)

if (CMAKE_SIZEOF_VOID_P EQUAL 8)
    set (MGWHELP_NAME mgwhelp-x64)
    set (MGWHELP_DEF mgwhelp64.def)
else ()
    set (MGWHELP_NAME mgwhelp)
    set (MGWHELP_DEF mgwhelp32.def)
endif ()

add_library (${MGWHELP_NAME} SHARED
    ${MGWHELP_DEF}
    demangle.cxx
    dwarf_pe.c
    mgwhelp.c
)
target_link_libraries (${MGWHELP_NAME} LINK_PRIVATE
    common
    dwarf
    dbghelp
)
set_target_properties (${MGWHELP_NAME} PROPERTIES
    PREFIX ""
)
if (BINUTILS_FOUND)
    set_target_properties (${MGWHELP_NAME} PROPERTIES
	COMPILE_DEFINITIONS HAVE_BFD=1
    )
    target_link_libraries (${MGWHELP_NAME} LINK_PRIVATE
        ${BINUTILS_BFD_LIBRARY}
        ${BINUTILS_LIBERTY_LIBRARY}
    )
endif ()
install (TARGETS ${MGWHELP_NAME} RUNTIME DESTINATION bin)

if (CMAKE_SIZEOF_VOID_P EQUAL 4)
    # XXX: We need to use a custom import lib to avoid link failures
    string (REPLACE gcc dlltool DLLTOOL ${CMAKE_C_COMPILER})
    set (MGWHELP_IMPLIB ${CMAKE_CURRENT_BINARY_DIR}/libmgwhelp.a)
    add_custom_command (
        OUTPUT ${MGWHELP_IMPLIB}
	COMMAND ${DLLTOOL} --output-lib ${MGWHELP_IMPLIB} --dllname ${MGWHELP_NAME}.dll --kill-at --input-def=${CMAKE_CURRENT_SOURCE_DIR}/dbghelp.def
	DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/dbghelp.def
    )
else ()
    set (MGWHELP_IMPLIB ${MGWHELP_NAME})
endif ()
set (MGWHELP_IMPLIB ${MGWHELP_IMPLIB} PARENT_SCOPE)
add_custom_target (mgwhelp_implib DEPENDS ${MGWHELP_IMPLIB})


add_executable (drmingw WIN32
    debugger.c
    dialog.c
    log.c
    main.c
    resource.rc
)
set_target_properties (drmingw PROPERTIES
    COMPILE_DEFINITIONS "PACKAGE=\"DrMingw\";VERSION=\"${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH}\""
)
add_dependencies (drmingw mgwhelp_implib)
target_link_libraries (drmingw
    common
    ${MGWHELP_IMPLIB}
)
install (TARGETS drmingw RUNTIME DESTINATION bin)

add_library (exchndl MODULE
    exchndl.c
    exchndl.def
)
add_dependencies (exchndl mgwhelp_implib)
target_link_libraries (exchndl LINK_PRIVATE
    ${RUBY_LIBRARY}
    common
    ${MGWHELP_IMPLIB}
)
set_target_properties (exchndl PROPERTIES
    PREFIX ""
)
install (TARGETS exchndl LIBRARY DESTINATION bin)

add_executable (addr2line
    addr2line.cpp
)
add_dependencies (addr2line mgwhelp_implib)
target_link_libraries (addr2line
    ${MGWHELP_IMPLIB}
)

# Bundle DbgHelp and SymSrv DLLs
if (WINDBG_FOUND)
    install (
        FILES
            "${WINDBG_DIR}/dbghelp.dll"
            "${WINDBG_DIR}/symsrv.dll"
            "${WINDBG_DIR}/symsrv.yes"
        DESTINATION bin
    )
endif ()
