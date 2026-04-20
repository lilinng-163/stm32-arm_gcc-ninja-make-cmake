#!/bin/bash
# 该脚本使用git bash类linux环境执行，能实现在windows环境下使用openocd烧录程序到stm32f103c8t6
OPENOCD_PATH="/d/openocd/xpack-openocd-0.12.0-7-win32-x64/xpack-openocd-0.12.0-7/openocd"


openocd -f ${OPENOCD_PATH}/scripts/interface/stlink-v2-1.cfg \
        -f ${OPENOCD_PATH}/scripts/target/stm32f1x.cfg \
        -c "init" \
        -c "halt" \
        -c "flash write_image erase build/$(basename "$PWD").bin 0x08000000" \
        -c "verify_image build/$(basename "$PWD").bin 0x08000000" \
        -c "reset run" \
        -c "shutdown" 