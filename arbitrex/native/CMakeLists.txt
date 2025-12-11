cmake_minimum_required(VERSION 3.15)
project(arbitrex_native_mt5)

find_package(Python COMPONENTS Interpreter Development REQUIRED)

# Try to find pybind11 via system/vcpkg; if not present, fall back to
# fetching a pinned pybind11 via FetchContent to make local dev easier.
find_package(pybind11 QUIET)
if (NOT pybind11_FOUND)
    message(STATUS "pybind11 not found via package manager; fetching pybind11 via FetchContent")
    include(FetchContent)
    FetchContent_Declare(
        pybind11
        GIT_REPOSITORY https://github.com/pybind/pybind11.git
        # Use a modern pybind11 tag compatible with CMake >= 3.15
        GIT_TAG v2.12.1
    )
    FetchContent_MakeAvailable(pybind11)
endif()

pybind11_add_module(native_mt5 native_mt5.cpp)

set_target_properties(native_mt5 PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED YES
)

# Optional Arrow/Plasma native helpers. Only add when Arrow is found.
option(BUILD_ARROW "Enable building native_arrow_helpers (requires Arrow C++/Plasma)" OFF)

if(BUILD_ARROW)
    # Require Arrow C++ when Arrow support is explicitly requested.
    find_package(Arrow REQUIRED)
    if(Arrow_FOUND)
        message(STATUS "Arrow C++ found; building native_arrow_helpers module")
        pybind11_add_module(native_arrow_helpers native_arrow_helpers.cpp)
        set_target_properties(native_arrow_helpers PROPERTIES
            CXX_STANDARD 17
            CXX_STANDARD_REQUIRED YES
        )
        target_include_directories(native_arrow_helpers PRIVATE ${ARROW_INCLUDE_DIRS})
        target_link_libraries(native_arrow_helpers PRIVATE ${ARROW_LIBRARIES})
        target_compile_definitions(native_arrow_helpers PRIVATE ARROW_FOUND=1)
        # Try to find plasma lib for direct native Plasma writes
        find_library(PLASMA_LIB NAMES plasma libplasma)
        if(PLASMA_LIB)
            message(STATUS "Plasma library found; enabling native Plasma support")
            target_link_libraries(native_arrow_helpers PRIVATE ${PLASMA_LIB})
            target_compile_definitions(native_arrow_helpers PRIVATE PLASMA_FOUND=1)
        else()
            message(STATUS "Plasma library not found; native Plasma writes disabled")
        endif()
    else()
        message(FATAL_ERROR "BUILD_ARROW=ON but Arrow C++ libraries not found")
    endif()
else()
    message(STATUS "BUILD_ARROW=OFF (native_arrow_helpers disabled)")
endif()
