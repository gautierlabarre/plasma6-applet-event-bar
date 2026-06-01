cmake_minimum_required(VERSION 3.16)
project(plasma-applet-event-bar)

set(PROJECT_VERSION "0.1.0")
set(KF_MIN_VERSION "6.0.0")
set(PLASMA_MIN_VERSION "6.0.0")

find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)

find_package(Plasma ${PLASMA_MIN_VERSION} REQUIRED)

plasma_install_package(package org.kde.plasma.eventbar)
