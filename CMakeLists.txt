cmake_minimum_required(VERSION 3.16)
project(StellarTexto LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_PREFIX_PATH "/opt/qt/6.11.2/gcc_64" ${CMAKE_PREFIX_PATH})
set(CMAKE_INSTALL_RPATH "/opt/qt/6.11.2/gcc_64/lib")
set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets PrintSupport)

add_executable(StellarTexto
    main.cpp
    mainwindow.cpp
    codeeditor.cpp
    syntaxhighlighter.cpp
    finddialog.cpp
    resources.qrc
)

target_link_libraries(StellarTexto PRIVATE Qt6::Widgets Qt6::PrintSupport)
