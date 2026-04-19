set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR arm)
cmake_minimum_required(VERSION 3.11)

# 让CMake在尝试编译测试程序时生成静态库而不是可执行文件,因为交叉编译器无法运行生成的可执行文件
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(cross_compile_prefix arm-none-eabi-)
set(CMAKE_C_COMPILER ${cross_compile_prefix}gcc)
set(CMAKE_CXX_COMPILER ${cross_compile_prefix}g++)
set(CMAKE_ASM_COMPILER ${cross_compile_prefix}gcc)
set(CMAKE_AR ${cross_compile_prefix}ar)
set(CMAKE_OBJCOPY ${cross_compile_prefix}objcopy)
set(CMAKE_OBJDUMP ${cross_compile_prefix}size)

project(template C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# 添加预处理宏
add_compile_definitions(ARM_MATH_CM3)

# 添加类似C_FLAGS
# 软件浮点
add_compile_options(-mfloat-abi=soft)
# 为编译器指定cpu架构 启用thumb指令集(cortex-m标准指令集) 启用thumb/arm指令集混用
add_compile_options(-mcpu=cortex-m3 -mthumb -mthumb-interwork)
# 函数独立分段
# 数据独立分段 和函数独立分段搭配能大幅减小固件体积(连接器同步删除未使用的全局/静态变量)
# 禁止公共块 禁止多个文件的同名全局变量合并 能在编译时报错
# 编译日志单行显示
add_compile_options(-ffunction-sections -fdata-sections -fno-common -fmessage-length=0)

# C++17废弃了register关键字，但是hal/cmsis的库可能残留，此选项强制关闭该警告
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-register")


# 以下四个模式是cmake定义的
# 发行版，优化力度最大
# 给变量加入""保护变量，如果CMAKE_BUILD_TYPE为空就是""
# STREQUAL 是否相等
if ("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
    message(VERBOSE "Maximum optimization for speed")
    add_compile_options(-Ofast)
# 极速+调试
elseif ("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")
    message(VERBOSE "Maximum optimization for speed, debug info included")
    add_compile_options(-Ofast -g)
# 最小体积
elseif ("${CMAKE_BUILD_TYPE}" STREQUAL "MinSizeRel")
    message(VERBOSE "Maximum optimization for size")
    add_compile_options(-Os)
# 调试 Debug
else ()
    message(VERBOSE "Minimal optimization, debug info included")
    add_compile_options(-Og -g)
endif ()

# 和add_compile_definitions一样，只不过是旧命令
# 必须加上-D 前缀,add_compile_definitions不需要
add_definitions(-DUSE_HAL_DRIVER -DSTM32F103xB)

# 头文件路径
include_directories(./Lib/Inc ./User/Inc)

#搜索源文件
file(GLOB SOURCES ./Lib/Src/*.c ./User/Src/*.c ./Startup/*.s ./Cmake/*.*)

# 添加脚本
set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/Cmake/STM32F103XX_FLASH.ld)

# 添加链接器选项
# gcc规定编译器不认识的需要传给链接的参数,需要加入-Wl并用,分割
# 自动删除没用的代码，需要配合前面的编译阶段的-ffunction-sections -fdata-sections
# 编译完成后打印Flash和Ram的使用情况
# 生成内存映射文件，用于调试时看函数和变量
add_link_options(-Wl,-gc-sections,--print-memory-usage,-Map=${PROJECT_BINARY_DIR}/${PROJECT_NAME}.map)

# 此处为编译器认识的参数,但是需要单独再次为链接器指定cpu架构
add_link_options(-mcpu=cortex-m3 -mthumb -mthumb-interwork)

# 指定链接脚本
add_link_options(-T ${LINKER_SCRIPT})

# 使用微型clib
# 适配误操作系统的单片机,屏蔽系统依赖
# 开启printf打印浮点数的功能
add_link_options(-specs=nano.specs -specs=nosys.specs -u _printf_float)

add_executable(${PROJECT_NAME}.elf ${SOURCES} ${LINKER_SCRIPT})

# 设置烧录文件存放位置
# PROJECT_BINARY_DIR 自动进入build目录
set(HEX_FILE ${PROJECT_BINARY_DIR}/${PROJECT_NAME}.hex)
set(BIN_FILE ${PROJECT_BINARY_DIR}/${PROJECT_NAME}.bin)

# add_custom_command 额外执行命令
# 自动格式转换
# TARGET ${PROJECT_NAME}.elf 针对这个程序文件,等它生成完毕
# COMMENT 控制台打印提示
# $<关键字:参数> 编译完成时确定的变量
# $<TARGET_FILE:${PROJECT_NAME}.elf> 获取目标.elf文件
add_custom_command(TARGET ${PROJECT_NAME}.elf POST_BUILD    #等elf文件生成后执行
                   COMMAND ${CMAKE_OBJCOPY} -Oihex $<TARGET_FILE:${PROJECT_NAME}.elf> ${HEX_FILE}
                   COMMAND ${CMAKE_OBJCOPY} -Obinary $<TARGET_FILE:${PROJECT_NAME}.elf> ${BIN_FILE}   
                   COMMENT "Building ${HEX_FILE}
Building ${BIN_FILE}")                   