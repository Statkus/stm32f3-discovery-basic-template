SRC_DIR ?= src
INC_DIR ?= inc

SRCS = $(wildcard $(SRC_DIR)/*.c)
SRCS_NO_DIR = $(notdir $(SRCS))

PROJECT_NAME ?= main

# Location of the STM32F3xx Standard Peripheral Library
STD_PERIPH_LIB_DIR = Libraries

# Location of the linker scripts
LDSCRIPTS_DIR = Device/ldscripts

# Location of OpenOCD board .cfg files
OPENOCD_BOARD_DIR = /usr/share/openocd/scripts/board

###################################################

CC      = arm-none-eabi-gcc
GDB     = arm-none-eabi-gdb
OBJCOPY = arm-none-eabi-objcopy
OBJDUMP = arm-none-eabi-objdump
SIZE    = arm-none-eabi-size

CFLAGS  = -Wall -g -std=c99 -Os
CFLAGS += -mlittle-endian -mcpu=cortex-m4  -march=armv7e-m -mthumb
CFLAGS += -mfpu=fpv4-sp-d16 -mfloat-abi=hard
CFLAGS += -ffunction-sections -fdata-sections

LDFLAGS += -Wl,--gc-sections -Wl,-Map=$(PROJECT_NAME).map

###################################################

vpath %.a $(STD_PERIPH_LIB_DIR)

CFLAGS += -I $(INC_DIR)
CFLAGS += -I $(STD_PERIPH_LIB_DIR)
CFLAGS += -I $(STD_PERIPH_LIB_DIR)/CMSIS/Device/ST/STM32F30x/Include
CFLAGS += -I $(STD_PERIPH_LIB_DIR)/CMSIS/Include
CFLAGS += -I $(STD_PERIPH_LIB_DIR)/STM32F30x_StdPeriph_Driver/inc
CFLAGS += -I $(STD_PERIPH_LIB_DIR)/STM32_USB-FS-Device_Driver/inc
CFLAGS += -include $(STD_PERIPH_LIB_DIR)/stm32f30x_conf.h

STARTUP = Device/startup_stm32f30x.s # add startup file to build

OBJS = $(addprefix objs/,$(SRCS_NO_DIR:.c=.o))
DEPS = $(addprefix deps/,$(SRCS_NO_DIR:.c=.d))

###################################################

.PHONY: all lib proj flash debug clean

all: lib proj

-include $(DEPS)

lib:
	$(MAKE) -C $(STD_PERIPH_LIB_DIR)

proj: $(PROJECT_NAME).elf

dirs:
	mkdir -p deps objs

objs/%.o : $(SRC_DIR)/%.c dirs
	$(CC) $(CFLAGS) -c -o $@ $< -MMD -MF deps/$(*F).d

$(PROJECT_NAME).elf: $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@ $(STARTUP) -L$(STD_PERIPH_LIB_DIR) -lstm32f3 -L$(LDSCRIPTS_DIR) -Tstm32f3.ld
	$(OBJCOPY) -O binary $(PROJECT_NAME).elf $(PROJECT_NAME).bin
	$(SIZE) $(PROJECT_NAME).elf

flash:
	openocd -f $(OPENOCD_BOARD_DIR)/stm32f3discovery.cfg -c "program `pwd`/$(PROJECT_NAME).bin verify reset exit 0x08000000"

debug: flash
	$(GDB) -x extra/gdb_cmds $(PROJECT_NAME).elf

clean:
	$(MAKE) -C $(STD_PERIPH_LIB_DIR) clean
	rm -rf objs
	rm -rf deps
	rm -f $(PROJECT_NAME).elf
	rm -f $(PROJECT_NAME).bin
	rm -f $(PROJECT_NAME).map
