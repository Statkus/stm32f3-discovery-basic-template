SRC_DIR ?= src
INC_DIR ?= inc

SRCS = $(wildcard $(SRC_DIR)/*.c)
SRCS_NO_DIR = $(notdir $(SRCS))

# All the files will be generated with this name (main.elf, main.bin, main.hex, etc)
PROJECT_NAME = main

# Location of the Libraries folder from the STM32F3xx Standard Peripheral Library
STD_PERIPH_LIB = Libraries

# Location of the linker scripts
LDSCRIPT_INC=Device/ldscripts

# location of OpenOCD Board .cfg files (only used with 'make program')
OPENOCD_BOARD_DIR=/usr/share/openocd/scripts/board

# Configuration (cfg) file containing programming directives for OpenOCD
OPENOCD_PROC_FILE=extra/stm32f3-openocd.cfg

# that's it, no need to change anything below this line!

###################################################

CC=arm-none-eabi-gcc
GDB=arm-none-eabi-gdb
OBJCOPY=arm-none-eabi-objcopy
OBJDUMP=arm-none-eabi-objdump
SIZE=arm-none-eabi-size

CFLAGS  = -Wall -g -std=c99 -Os
CFLAGS += -mlittle-endian -mcpu=cortex-m4  -march=armv7e-m -mthumb
CFLAGS += -mfpu=fpv4-sp-d16 -mfloat-abi=hard
CFLAGS += -ffunction-sections -fdata-sections

LDFLAGS += -Wl,--gc-sections -Wl,-Map=$(PROJECT_NAME).map

###################################################

vpath %.a $(STD_PERIPH_LIB)

ROOT=$(shell pwd)

CFLAGS += -I $(INC_DIR)
CFLAGS += -I $(STD_PERIPH_LIB)
CFLAGS += -I $(STD_PERIPH_LIB)/CMSIS/Device/ST/STM32F30x/Include
CFLAGS += -I $(STD_PERIPH_LIB)/CMSIS/Include
CFLAGS += -I $(STD_PERIPH_LIB)/STM32F30x_StdPeriph_Driver/inc
CFLAGS += -I $(STD_PERIPH_LIB)/STM32_USB-FS-Device_Driver/inc
CFLAGS += -include $(STD_PERIPH_LIB)/stm32f30x_conf.h

STARTUP = Device/startup_stm32f30x.s # add startup file to build

OBJS = $(addprefix objs/,$(SRCS_NO_DIR:.c=.o))
DEPS = $(addprefix deps/,$(SRCS_NO_DIR:.c=.d))

###################################################

.PHONY: all lib proj program debug clean reallyclean

all: lib proj

-include $(DEPS)

lib:
	$(MAKE) -C $(STD_PERIPH_LIB)

proj: 	$(PROJECT_NAME).elf

dirs:
	mkdir -p deps objs
	touch dirs

objs/%.o : $(SRC_DIR)/%.c dirs
	$(CC) $(CFLAGS) -c -o $@ $< -MMD -MF deps/$(*F).d

$(PROJECT_NAME).elf: $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@ $(STARTUP) -L$(STD_PERIPH_LIB) -lstm32f3 -L$(LDSCRIPT_INC) -Tstm32f3.ld
	$(OBJCOPY) -O ihex $(PROJECT_NAME).elf $(PROJECT_NAME).hex
	$(OBJCOPY) -O binary $(PROJECT_NAME).elf $(PROJECT_NAME).bin
	$(OBJDUMP) -St $(PROJECT_NAME).elf >$(PROJECT_NAME).lst
	$(SIZE) $(PROJECT_NAME).elf

program:
	openocd -f $(OPENOCD_BOARD_DIR)/stm32f3discovery.cfg -f $(OPENOCD_PROC_FILE) -c "stm_flash `pwd`/$(PROJECT_NAME).bin" -c shutdown

debug: program
	$(GDB) -x extra/gdb_cmds $(PROJECT_NAME).elf

clean:
	find ./ -name '*~' | xargs rm -f	
	rm -f objs/*.o
	rm -f deps/*.d
	rm -f dirs
	rm -f $(PROJECT_NAME).elf
	rm -f $(PROJECT_NAME).hex
	rm -f $(PROJECT_NAME).bin
	rm -f $(PROJECT_NAME).map
	rm -f $(PROJECT_NAME).lst

reallyclean: clean
	$(MAKE) -C $(STD_PERIPH_LIB) clean
