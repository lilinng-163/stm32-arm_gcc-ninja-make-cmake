cmake_minimum_required(VERSION 3.11)

# 交叉编译工具链配置
set(CMAKE_SYSTEM_NAME Generic)  # 交叉编译工具链的系统名称,可以随便设置,不影响编译器的选择
set(CMAKE_SYSTEM_VERSION 1)     # 交叉编译工具链的系统版本,可以随便设置,不影响编译器的选择
set(CMAKE_SYSTEM_PROCESSOR arm) # 交叉编译工具链的处理器架构,可以随便设置,不影响编译器的选择

# 让CMake在尝试编译测试程序时生成静态库而不是可执行文件,因为交叉编译器无法运行生成的可执行文件,防止vscode报错
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(cross_compile_prefix arm-none-eabi-)
set(CMAKE_C_COMPILER ${cross_compile_prefix}gcc)
set(CMAKE_CXX_COMPILER ${cross_compile_prefix}g++)
set(CMAKE_ASM_COMPILER ${cross_compile_prefix}gcc)
set(CMAKE_AR ${cross_compile_prefix}ar)             # 生成静态库
set(CMAKE_OBJCOPY ${cross_compile_prefix}objcopy)   # 转.elf为.bin和.hex
set(CMAKE_OBJDUMP ${cross_compile_prefix}size)      # 查看.elf文件的内存使用情况
#还可以设置objdump为arm-none-eabi-objdump来查看反汇编代码等

# 项目名字和使用的语言,自动取文件夹名作为项目名字,也可以直接写死
get_filename_component(PRJ_NAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)
project(${PRJ_NAME} C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# ------------------------------------------------文件搜索组装-----------------------------------------
# 头文件路径
include_directories(./Lib/Inc ./Hardware/Inc ./User/Inc)

#搜索源文件
# 也可以编译成库文件,然后链接到目标文件,但是对于单片机项目来说没有必要,直接编译成可执行文件就行了
# 建议不使用file而是aux_source_directory
# HAL库配置有一些额外操作比如删掉template等
file(GLOB SOURCES ./Lib/Src/*.c ./Hardware/Src/*.c ./User/Src/*.c ./Startup/*.s ./Cmake/*.*)

# ------------------------------------------------预处理-----------------------------------------------
# 添加预处理宏
add_compile_definitions(ARM_MATH_CM3)
# 和add_compile_definitions一样，只不过是旧命令
# 必须加上-D 前缀,add_compile_definitions不需要
add_definitions(-DUSE_HAL_DRIVER -DSTM32F103xB)

# ------------------------------------------------编译-----------------------------------------------
# 添加类似C_FLAGS
# -mabi不需要指定,arm-none-eabi-gcc默认就是eabi
# 小端模式(-mlittle-endian)默认不添加,编译器默认小端模式
# -march -mtune不需要指定,-mcpu会自动推导
# 为编译器指定cpu架构 启用thumb指令集(cortex-m标准指令集) 启用thumb/arm指令集混用
add_compile_options(-mcpu=cortex-m3 -mthumb -mthumb-interwork)

# 软件浮点
add_compile_options(-mfloat-abi=soft)

# 硬件浮点
# -mfpu后面的参数见https://gcc.gnu.org/onlinedocs/gcc/ARM-Options.html?spm=5176.28103460.0.0.96a02988u8SWb1
# add_compile_options(-mfloat-abi=hard -mfpu=fpv4-sp-d16)
# 半精度浮点 16位存储(需要指定fpu,硬件浮点)
# none,ieee(标准格式),alternative(arm特化)
# add_compile_options(-mfloat-abi=hard -mfpu=fpv4-sp-d16 -mfp16-format=ieee)

# 函数独立分段
# 数据独立分段 和函数独立分段搭配能大幅减小固件体积(连接器同步删除未使用的全局/静态变量)
# 禁止公共块 禁止多个文件的同名全局变量合并 能在编译时报错
# 编译日志单行显示
add_compile_options(-ffunction-sections -fdata-sections -fno-common -fmessage-length=0)

# -mstucture-size-boudary强烈不建议使用

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

# ------------------------------------------------汇编-----------------------------------------------
# 在汇编阶段,arm-none-eabi-gcc会自动识别.s文件为汇编文件,并调用汇编器进行编译,不需要额外指定编译器选项,只需要添加.s文件到源文件列表中即可
# ------------------------------------------------链接-----------------------------------------------
# 添加脚本
set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/Cmake/STM32F103XX_FLASH.ld)
# 指定链接脚本
add_link_options(-T ${LINKER_SCRIPT})

# 添加链接器选项
# gcc规定编译器不认识的需要传给链接的参数,需要加入-Wl并用,分割
# 自动删除没用的代码，需要配合前面的编译阶段的-ffunction-sections -fdata-sections
# 编译完成后打印Flash和Ram的使用情况
# 生成内存映射文件，用于调试时看函数和变量
add_link_options(-Wl,-gc-sections,--print-memory-usage,-Map=${PROJECT_BINARY_DIR}/${PROJECT_NAME}.map)

# 此处为编译器认识的参数,但是需要单独再次为链接器指定cpu架构
add_link_options(-mcpu=cortex-m3 -mthumb -mthumb-interwork)


# 使用微型clib
# 适配误操作系统的单片机,屏蔽系统依赖
# 开启printf打印浮点数的功能
add_link_options(-specs=nano.specs -specs=nosys.specs -u _printf_float)


# 生成目标文件
add_executable(${PROJECT_NAME}.elf ${SOURCES} ${LINKER_SCRIPT})

# 设置烧录文件存放位置
# PROJECT_BINARY_DIR 指向运行cmake命令的文件夹,即自动进入build目录
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