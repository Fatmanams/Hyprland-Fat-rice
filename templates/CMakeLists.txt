cmake_minimum_required(VERSION 3.20)
project(zed-sample LANGUAGES C CXX)

# Output lands in build/Debug/ with the Visual Studio generator (the
# Windows default when Build Tools are installed) and in build/ with
# single-config generators such as Ninja or Unix Makefiles.
add_executable(hello_c src/main.c)
add_executable(hello_cpp src/main.cpp)
