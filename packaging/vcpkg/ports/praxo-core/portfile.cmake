vcpkg_from_git(
    URL https://github.com/axisvela/praxo-core.git
    REF d00308d30facc24f81adb860b2a9f4ad28f99722
    OUT_SOURCE_PATH SOURCE_PATH
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/language/c"
    OPTIONS
        -DBUILD_TESTING=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(
    PACKAGE_NAME praxo-core
    CONFIG_PATH lib/cmake/praxo-core
)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
