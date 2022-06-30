cmake_minimum_required(VERSION 3.8)
project(search_faces)
set(TARGET_NAME "${PROJECT_NAME}")
set(CMAKE_CXX_STANDARD 20)
find_package(Boost COMPONENTS program_options REQUIRED)
add_subdirectory(${PROJECT_SOURCE_DIR}/contrib)

list(APPEND SOURCE_CORE main.cpp)
add_executable(${TARGET_NAME} ${SOURCE_CORE})

target_link_libraries(${TARGET_NAME} mysqlconncpp_library crow_library abseil_library Boost::program_options)
