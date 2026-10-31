# Generated Cmake Pico project file

cmake_minimum_required(VERSION 3.13)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Initialise pico_sdk from installed location
# (note this can come from environment, CMake cache etc)

# == DO NOT EDIT THE FOLLOWING LINES for the Raspberry Pi Pico VS Code Extension to work ==
if(WIN32)
    set(USERHOME $ENV{USERPROFILE})
else()
    set(USERHOME $ENV{HOME})
endif()
set(sdkVersion 2.3.1)
set(toolchainVersion 15_2_Rel1)
set(picotoolVersion 2.3.1)
set(picoVscode ${USERHOME}/.pico-sdk/cmake/pico-vscode.cmake)
if (EXISTS ${picoVscode})
    include(${picoVscode})
endif()
# ====================================================================================
set(PICO_BOARD pico2_w CACHE STRING "Board type")

# Pull in Raspberry Pi Pico SDK (must be before project)
include(pico_sdk_import.cmake)

project(picoscribe C CXX ASM)

# Initialise the Raspberry Pi Pico SDK
pico_sdk_init()

# Add executable. Default name is the project name, version 0.1

add_executable(picoscribe
    src/main.c
    src/ble/ble_server.c
    src/usb/hid_keyboard.c
    src/usb/usb_descriptors.c
    )

pico_set_program_name(picoscribe "PicoScribe")
pico_set_program_version(picoscribe "0.1")

# Modify the below lines to enable/disable output over UART/USB
pico_enable_stdio_uart(picoscribe 1)
pico_enable_stdio_usb(picoscribe 0)

target_link_libraries(picoscribe
        pico_stdlib
        pico_util
        pico_multicore
        pico_cyw43_arch_none
        pico_btstack_cyw43 # enable bt
        pico_btstack_ble # ble support
        tinyusb_board
        tinyusb_device
        )

# Add the standard include files to the build
target_include_directories(picoscribe PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}/src
        ${CMAKE_CURRENT_LIST_DIR}/src/ble
        ${CMAKE_CURRENT_LIST_DIR}/src/usb
)

target_compile_definitions(picoscribe PRIVATE
    #WANT_HCI_DUMP=1
    $<$<CONFIG:Debug>:DEBUG_LOGGING>
)

pico_btstack_make_gatt_header(picoscribe PRIVATE "${CMAKE_CURRENT_LIST_DIR}/src/ble/picoscribe.gatt")
pico_add_extra_outputs(picoscribe)

