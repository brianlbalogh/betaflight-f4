###############################################################################
# "THE BEER-WARE LICENSE" (Revision 42):
# <msmith@FreeBSD.ORG> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return
###############################################################################
#
# Makefile for building the cleanflight firmware.
#
# Invoke this with 'make help' to see the list of supported targets.
#

###############################################################################


# Things that the user might override on the commandline
#

# The target to build, see VALID_TARGETS below
TARGET		?= NAZE

# Compile-time options
OPTIONS		?=

# compile for OpenPilot BootLoader support
OPBL ?=no

# Debugger optons, must be empty or GDB
DEBUG ?=

# Insert the debugging hardfault debugger
# releases should not be built with this flag as it does not disable pwm output
DEBUG_HARDFAULTS ?=

# Serial port/Device for flashing
SERIAL_DEVICE	?= $(firstword $(wildcard /dev/ttyUSB*) no-port-found)

# Flash size (KB).  Some low-end chips actually have more flash than advertised, use this to override.
FLASH_SIZE ?=

###############################################################################
# Things that need to be maintained as the source changes
#

FORKNAME			 = betaflight-f4

CC3D_TARGETS = CC3D CC3D_OPBL
F1_TARGETS = NAZE OLIMEXINO CJMCU EUSTM32F103RC PORT103R ALIENFLIGHTF1 AFROMINI
F3_TARGETS = STM32F3DISCOVERY CHEBUZZF3 NAZE32PRO SPRACINGF3 IRCFUSIONF3 SPARKY ALIENFLIGHTF3 COLIBRI_RACE LUX_RACE MOTOLAB RMDO SPRACINGF3MINI SPRACINGF3EVO DOGE SINGULARITY
F4_TARGETS = REVO REVO_OPBL SPARKY2 SPARKY2_OPBL REVONANO REVONANO_OPBL ALIENFLIGHTF4 BLUEJAYF4 VRCORE QUANTON QUANTON_OPBL AQ32_V2

F405_TARGETS = REVO REVO_OPBL SPARKY2 SPARKY2_OPBL ALIENFLIGHTF4 BLUEJAYF4 VRCORE QUANTON QUANTON_OPBL AQ32_V2
F405_TARGETS_16 = QUANTON QUANTON_OPBL
F411_TARGETS = REVONANO REVONANO_OPBL

SDCARD_TARGETS = ALIENFLIGHTF4 BLUEJAYF4 SPRACINGF3MINI AQ32_V2

VALID_TARGETS   = $(F1_TARGETS) $(CC3D_TARGETS) $(F3_TARGETS) $(F4_TARGETS)

# Valid targets for OP VCP support
VCP_VALID_TARGETS = $(CC3D_TARGETS)

# Valid targets for OP BootLoader support
OPBL_VALID_TARGETS = CC3D_OPBL REVO_OPBL REVONANO_OPBL SPARKY2_OPBL QUANTON_OPBL

64K_TARGETS  = CJMCU
128K_TARGETS = ALIENFLIGHTF1 $(CC3D_TARGETS) NAZE OLIMEXINO RMDO AFROMINI
256K_TARGETS = EUSTM32F103RC PORT103R STM32F3DISCOVERY CHEBUZZF3 NAZE32PRO SPRACINGF3 IRCFUSIONF3 SPARKY ALIENFLIGHTF3 COLIBRI_RACE LUX_RACE MOTOLAB SPRACINGF3MINI SPRACINGF3EVO DOGE SINGULARITY $(F4_TARGETS)

# note that there is no hardfault debugging startup file assembly handler for other platforms
ifeq ($(DEBUG_HARDFAULTS),F3)
CFLAGS += -DDEBUG_HARDFAULTS
STM32F30x_COMMON_SRC = startup_stm32f3_debug_hardfault_handler.S
else
STM32F30x_COMMON_SRC = startup_stm32f30x_md_gcc.S
endif

# Configure default flash sizes for the targets
ifeq ($(FLASH_SIZE),)
ifeq ($(TARGET),$(filter $(TARGET),$(64K_TARGETS)))
FLASH_SIZE = 64
else ifeq ($(TARGET),$(filter $(TARGET),$(128K_TARGETS)))
FLASH_SIZE = 128
else ifeq ($(TARGET),$(filter $(TARGET),$(256K_TARGETS)))
FLASH_SIZE = 256
else
$(error FLASH_SIZE not configured for target $(TARGET))
endif
endif

REVISION = $(shell git log -1 --format="%h")

FC_VER_MAJOR := $(shell grep " FC_VERSION_MAJOR" src/main/version.h | awk '{print $$3}' )
FC_VER_MINOR := $(shell grep " FC_VERSION_MINOR" src/main/version.h | awk '{print $$3}' )
FC_VER_PATCH := $(shell grep " FC_VERSION_PATCH" src/main/version.h | awk '{print $$3}' )

FC_VER := $(FC_VER_MAJOR).$(FC_VER_MINOR).$(FC_VER_PATCH)

# Working directories
ROOT		 := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR		 = $(ROOT)/src/main
OBJECT_DIR	 = $(ROOT)/obj/main
BIN_DIR		 = $(ROOT)/obj
CMSIS_DIR	 = $(ROOT)/lib/main/CMSIS
INCLUDE_DIRS	 = $(SRC_DIR)
LINKER_DIR	 = $(ROOT)/src/main/target

# Search path for sources
VPATH		:= $(SRC_DIR):$(SRC_DIR)/startup
USBFS_DIR	= $(ROOT)/lib/main/STM32_USB-FS-Device_Driver
USBPERIPH_SRC = $(notdir $(wildcard $(USBFS_DIR)/src/*.c))

CSOURCES        := $(shell find $(SRC_DIR) -name '*.c')

ifeq ($(TARGET),$(filter $(TARGET),$(F3_TARGETS)))

STDPERIPH_DIR	= $(ROOT)/lib/main/STM32F30x_StdPeriph_Driver

STDPERIPH_SRC = $(notdir $(wildcard $(STDPERIPH_DIR)/src/*.c))

EXCLUDES	= stm32f30x_crc.c \
		stm32f30x_can.c

STDPERIPH_SRC := $(filter-out ${EXCLUDES}, $(STDPERIPH_SRC))

DEVICE_STDPERIPH_SRC = \
		$(STDPERIPH_SRC)


VPATH		:= $(VPATH):$(CMSIS_DIR)/CM1/CoreSupport:$(CMSIS_DIR)/CM1/DeviceSupport/ST/STM32F30x
CMSIS_SRC	 = $(notdir $(wildcard $(CMSIS_DIR)/CM1/CoreSupport/*.c \
			   $(CMSIS_DIR)/CM1/DeviceSupport/ST/STM32F30x/*.c))

INCLUDE_DIRS := $(INCLUDE_DIRS) \
		   $(STDPERIPH_DIR)/inc \
		   $(CMSIS_DIR)/CM1/CoreSupport \
		   $(CMSIS_DIR)/CM1/DeviceSupport/ST/STM32F30x

ifneq ($(TARGET),$(filter $(TARGET),SPRACINGF3 IRCFUSIONF3))
INCLUDE_DIRS := $(INCLUDE_DIRS) \
		   $(USBFS_DIR)/inc \
		   $(ROOT)/src/main/vcp

VPATH := $(VPATH):$(USBFS_DIR)/src

DEVICE_STDPERIPH_SRC := $(DEVICE_STDPERIPH_SRC)\
		   $(USBPERIPH_SRC) 

endif

ifeq ($(TARGET),$(filter $(TARGET),$(SDCARD_TARGET)))
INCLUDE_DIRS := $(INCLUDE_DIRS) \
		   $(FATFS_DIR) 

VPATH := $(VPATH):$(FATFS_DIR)
endif

LD_SCRIPT	 = $(LINKER_DIR)/stm32_flash_f303_$(FLASH_SIZE)k.ld

ARCH_FLAGS	 = -mthumb -mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16 -fsingle-precision-constant -Wdouble-promotion
DEVICE_FLAGS = -DSTM32F303xC -DSTM32F303
TARGET_FLAGS = -D$(TARGET)
ifeq ($(TARGET),CHEBUZZF3)
# CHEBUZZ is a VARIANT of STM32F3DISCOVERY
TARGET_FLAGS := $(TARGET_FLAGS) -DSTM32F3DISCOVERY 
endif

ifeq ($(TARGET),$(filter $(TARGET),RMDO IRCFUSIONF3))
# RMDO and IRCFUSIONF3 are a VARIANT of SPRACINGF3
TARGET_FLAGS := $(TARGET_FLAGS) -DSPRACINGF3
endif

else ifeq ($(TARGET),$(filter $(TARGET), $(F4_TARGETS)))

#STDPERIPH
STDPERIPH_DIR  = $(ROOT)/lib/main/STM32F4xx_StdPeriph_Driver
STDPERIPH_SRC = $(notdir $(wildcard $(STDPERIPH_DIR)/src/*.c))
EXCLUDES = stm32f4xx_crc.c \
               stm32f4xx_can.c \
               stm32f4xx_fmc.c \
               stm32f4xx_sai.c \
               stm32f4xx_cec.c \
               stm32f4xx_dsi.c \
               stm32f4xx_flash_ramfunc.c \
               stm32f4xx_fmpi2c.c \
               stm32f4xx_lptim.c \
               stm32f4xx_qspi.c \
               stm32f4xx_spdifrx.c
               

ifeq ($(TARGET),$(filter $(TARGET), $(F411_TARGETS)))
EXCLUDES += stm32f4xx_fsmc.c
endif

STDPERIPH_SRC := $(filter-out ${EXCLUDES}, $(STDPERIPH_SRC))

#USB
USBCORE_DIR    = $(ROOT)/lib/main/STM32_USB_Device_Library/Core
USBCORE_SRC = $(notdir $(wildcard $(USBCORE_DIR)/src/*.c))
USBOTG_DIR     = $(ROOT)/lib/main/STM32_USB_OTG_Driver
USBOTG_SRC = $(notdir $(wildcard $(USBOTG_DIR)/src/*.c))
EXCLUDES       = usb_bsp_template.c \
               usb_conf_template.c \
               usb_hcd_int.c \
               usb_hcd.c \
               usb_otg.c

USBOTG_SRC := $(filter-out ${EXCLUDES}, $(USBOTG_SRC))
USBCDC_DIR     = $(ROOT)/lib/main/STM32_USB_Device_Library/Class/cdc
USBCDC_SRC = $(notdir $(wildcard $(USBCDC_DIR)/src/*.c))
EXCLUDES       = usbd_cdc_if_template.c
USBCDC_SRC := $(filter-out ${EXCLUDES}, $(USBCDC_SRC))
VPATH := $(VPATH):$(USBOTG_DIR)/src:$(USBCORE_DIR)/src:$(USBCDC_DIR)/src

DEVICE_STDPERIPH_SRC := $(STDPERIPH_SRC) \
                  $(USBOTG_SRC) \
                  $(USBCORE_SRC) \
                  $(USBCDC_SRC)

#CMSIS
VPATH          := $(VPATH):$(CMSIS_DIR)/CM4/CoreSupport:$(CMSIS_DIR)/CM4/DeviceSupport/ST/STM32F4xx
CMSIS_SRC       = $(notdir $(wildcard $(CMSIS_DIR)/CM4/CoreSupport/*.c \
                          $(CMSIS_DIR)/CM4/DeviceSupport/ST/STM32F4xx/*.c))
INCLUDE_DIRS := $(INCLUDE_DIRS) \
                  $(STDPERIPH_DIR)/inc \
                  $(USBOTG_DIR)/inc \
                  $(USBCORE_DIR)/inc \
                  $(USBCDC_DIR)/inc \
                  $(CMSIS_DIR)/CM4/CoreSupport \
                  $(CMSIS_DIR)/CM4/DeviceSupport/ST/STM32F4xx \
                  $(ROOT)/src/main/vcpf4

#Flags
ARCH_FLAGS      = -mthumb -mcpu=cortex-m4 -march=armv7e-m -mfloat-abi=hard -mfpu=fpv4-sp-d16 -fsingle-precision-constant -Wdouble-promotion

ifeq ($(TARGET),$(filter $(TARGET),$(F411_TARGETS)))
DEVICE_FLAGS = -DSTM32F411xE
DEVICE_FLAGS += -DHSE_VALUE=8000000
LD_SCRIPT       = $(LINKER_DIR)/stm32_flash_f411.ld
else ifeq ($(TARGET),$(filter $(TARGET),$(F405_TARGETS_16)))
DEVICE_FLAGS = -DSTM32F40_41xxx
DEVICE_FLAGS += -DHSE_VALUE=16000000
LD_SCRIPT       = $(LINKER_DIR)/stm32_flash_f405.ld
else ifeq ($(TARGET),$(filter $(TARGET),$(F405_TARGETS)))
DEVICE_FLAGS = -DSTM32F40_41xxx
DEVICE_FLAGS += -DHSE_VALUE=8000000
LD_SCRIPT       = $(LINKER_DIR)/stm32_flash_f405.ld
else
$(error Unknown MCU for F4 target)
endif

TARGET_FLAGS = -D$(TARGET)


else ifeq ($(TARGET),$(filter $(TARGET),EUSTM32F103RC PORT103R))


STDPERIPH_DIR	 = $(ROOT)/lib/main/STM32F10x_StdPeriph_Driver

STDPERIPH_SRC = $(notdir $(wildcard $(STDPERIPH_DIR)/src/*.c))

EXCLUDES	= stm32f10x_crc.c \
		stm32f10x_cec.c \
		stm32f10x_can.c

STDPERIPH_SRC := $(filter-out ${EXCLUDES}, $(STDPERIPH_SRC))

# Search path and source files for the CMSIS sources
VPATH		:= $(VPATH):$(CMSIS_DIR)/CM3/CoreSupport:$(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x
CMSIS_SRC	 = $(notdir $(wildcard $(CMSIS_DIR)/CM3/CoreSupport/*.c \
			   $(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x/*.c))

INCLUDE_DIRS := $(INCLUDE_DIRS) \
		   $(STDPERIPH_DIR)/inc \
		   $(CMSIS_DIR)/CM3/CoreSupport \
		   $(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x \

LD_SCRIPT	 = $(LINKER_DIR)/stm32_flash_f103_$(FLASH_SIZE)k.ld

ARCH_FLAGS	 = -mthumb -mcpu=cortex-m3
TARGET_FLAGS = -D$(TARGET) -pedantic
DEVICE_FLAGS = -DSTM32F10X_HD -DSTM32F10X

DEVICE_STDPERIPH_SRC = $(STDPERIPH_SRC)

else

STDPERIPH_DIR	 = $(ROOT)/lib/main/STM32F10x_StdPeriph_Driver

STDPERIPH_SRC = $(notdir $(wildcard $(STDPERIPH_DIR)/src/*.c))

EXCLUDES	= stm32f10x_crc.c \
		stm32f10x_cec.c \
		stm32f10x_can.c

STDPERIPH_SRC := $(filter-out ${EXCLUDES}, $(STDPERIPH_SRC))

# Search path and source files for the CMSIS sources
VPATH		:= $(VPATH):$(CMSIS_DIR)/CM3/CoreSupport:$(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x
CMSIS_SRC	 = $(notdir $(wildcard $(CMSIS_DIR)/CM3/CoreSupport/*.c \
			   $(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x/*.c))

INCLUDE_DIRS := $(INCLUDE_DIRS) \
		   $(STDPERIPH_DIR)/inc \
		   $(CMSIS_DIR)/CM3/CoreSupport \
		   $(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x \

DEVICE_STDPERIPH_SRC = $(STDPERIPH_SRC)

ifeq ($(TARGET),$(filter $(TARGET), $(VCP_VALID_TARGETS)))
INCLUDE_DIRS := $(INCLUDE_DIRS) \
		   $(USBFS_DIR)/inc \
		   $(ROOT)/src/main/vcp

VPATH := $(VPATH):$(USBFS_DIR)/src

DEVICE_STDPERIPH_SRC := $(DEVICE_STDPERIPH_SRC) \
		   $(USBPERIPH_SRC) 

endif

LD_SCRIPT	 = $(LINKER_DIR)/stm32_flash_f103_$(FLASH_SIZE)k.ld

ARCH_FLAGS	 = -mthumb -mcpu=cortex-m3
TARGET_FLAGS = -D$(TARGET) -pedantic
DEVICE_FLAGS = -DSTM32F10X_MD -DSTM32F10X

endif

ifneq ($(FLASH_SIZE),)
DEVICE_FLAGS := $(DEVICE_FLAGS) -DFLASH_SIZE=$(FLASH_SIZE)
endif

TARGET_DIR = $(ROOT)/src/main/target/$(TARGET)
TARGET_SRC = $(notdir $(wildcard $(TARGET_DIR)/*.c))

ifeq ($(TARGET),ALIENFLIGHTF1)
# ALIENFLIGHTF1 is a VARIANT of NAZE
TARGET_FLAGS := $(TARGET_FLAGS) -DNAZE -DALIENFLIGHT
TARGET_DIR = $(ROOT)/src/main/target/NAZE
endif

ifeq ($(TARGET),$(filter $(TARGET), $(CC3D_TARGETS)))
TARGET_FLAGS := $(TARGET_FLAGS) -DCC3D 
ifeq ($(TARGET),CC3D_OPBL)
TARGET_FLAGS := $(TARGET_FLAGS) -DCC3D_OPBL
endif
TARGET_DIR = $(ROOT)/src/main/target/CC3D
endif

ifeq ($(TARGET),$(filter $(TARGET), REVO_OPBL))
TARGET_FLAGS := $(TARGET_FLAGS) -DREVO
TARGET_DIR = $(ROOT)/src/main/target/REVO
TARGET_SRC = $(notdir $(wildcard $(TARGET_DIR)/*.c))
endif

ifeq ($(TARGET),$(filter $(TARGET), REVONANO_OPBL))
TARGET_FLAGS := $(TARGET_FLAGS) -DREVONANO
TARGET_DIR = $(ROOT)/src/main/target/REVONANO
TARGET_SRC = $(notdir $(wildcard $(TARGET_DIR)/*.c))
endif

ifeq ($(TARGET),$(filter $(TARGET), SPARKY2_OPBL))
TARGET_FLAGS := $(TARGET_FLAGS) -DSPARKY2
TARGET_DIR = $(ROOT)/src/main/target/SPARKY2
TARGET_SRC = $(notdir $(wildcard $(TARGET_DIR)/*.c))
endif

ifeq ($(TARGET),$(filter $(TARGET), QUANTON_OPBL))
TARGET_FLAGS := $(TARGET_FLAGS) -DQUANTON
TARGET_DIR = $(ROOT)/src/main/target/QUANTON
TARGET_SRC = $(notdir $(wildcard $(TARGET_DIR)/*.c))
endif

ifneq ($(filter $(TARGET),$(OPBL_VALID_TARGETS)),)
OPBL=yes
endif

ifeq ($(OPBL),yes)
ifneq ($(filter $(TARGET),$(OPBL_VALID_TARGETS)),)
TARGET_FLAGS := -DOPBL $(TARGET_FLAGS)
ifeq ($(TARGET),$(filter $(TARGET),$(F411_TARGETS)))
LD_SCRIPT       = $(LINKER_DIR)/stm32_flash_f411_bl.ld
else ifeq ($(TARGET),$(filter $(TARGET),$(F405_TARGETS)))
LD_SCRIPT       = $(LINKER_DIR)/stm32_flash_f405_bl.ld
else
LD_SCRIPT	 = $(LINKER_DIR)/stm32_flash_f103_$(FLASH_SIZE)k_opbl.ld
endif
.DEFAULT_GOAL := binary
else
$(error OPBL specified with a unsupported target)
endif
endif

ifeq ($(TARGET),AFROMINI)
# AFROMINI is a VARIANT of NAZE being recognized as rev4, but needs to use rev5 config
TARGET_FLAGS := $(TARGET_FLAGS) -DNAZE -DAFROMINI
TARGET_DIR = $(ROOT)/src/main/target/NAZE
endif

INCLUDE_DIRS := $(INCLUDE_DIRS) \
		    $(TARGET_DIR)

VPATH		:= $(VPATH):$(TARGET_DIR)

COMMON_SRC = build_config.c \
		   debug.c \
		   version.c \
		   $(TARGET_SRC) \
		   config/config.c \
		   config/runtime_config.c \
		   common/maths.c \
		   common/printf.c \
		   common/typeconversion.c \
		   common/encoding.c \
		   common/filter.c \
		   scheduler.c \
		   scheduler_tasks.c \
		   main.c \
		   mw.c \
		   flight/altitudehold.c \
		   flight/failsafe.c \
		   flight/pid.c \
		   flight/imu.c \
		   flight/mixer.c \
		   drivers/bus_i2c_soft.c \
                   drivers/exti.c \
                   drivers/io.c \
                   drivers/rcc.c \
		   drivers/serial.c \
		   drivers/sound_beeper.c \
		   drivers/system.c \
		   drivers/gyro_sync.c \
		   drivers/buf_writer.c \
		   io/beeper.c \
		   io/rc_controls.c \
		   io/rc_curves.c \
		   io/serial.c \
		   io/serial_4way.c \
		   io/serial_4way_avrootloader.c \
		   io/serial_4way_stk500v2.c \
		   io/serial_cli.c \
		   io/serial_msp.c \
		   io/statusindicator.c \
		   rx/rx.c \
		   rx/pwm.c \
		   rx/msp.c \
		   rx/sbus.c \
		   rx/sumd.c \
		   rx/sumh.c \
		   rx/spektrum.c \
		   rx/xbus.c \
		   rx/ibus.c \
           rx/jetiexbus.c \
		   sensors/acceleration.c \
		   sensors/battery.c \
		   sensors/boardalignment.c \
		   sensors/compass.c \
		   sensors/gyro.c \
		   sensors/initialisation.c \
		   $(CMSIS_SRC) \
		   $(DEVICE_STDPERIPH_SRC)

HIGHEND_SRC = \
		   flight/navigation.c \
		   flight/gps_conversion.c \
		   common/colorconversion.c \
		   io/gps.c \
		   io/ledstrip.c \
		   io/display.c \
		   telemetry/telemetry.c \
		   telemetry/frsky.c \
		   telemetry/hott.c \
		   telemetry/smartport.c \
		   telemetry/ltm.c \
		   sensors/sonar.c \
		   sensors/barometer.c \
		   blackbox/blackbox.c \
		   blackbox/blackbox_io.c

STM32F10x_COMMON_SRC = \
                  startup_stm32f10x_md_gcc.S \
                  drivers/dma.c \
                  drivers/serial_softserial.c \
                  drivers/serial_uart.c \
                  drivers/serial_uart_stm32f10x.c \
                  drivers/system_stm32f10x.c \
                  drivers/pwm_mapping.c \
                  drivers/pwm_output.c \
                  drivers/pwm_rx.c \
                  drivers/timer.c \
                  drivers/timer_stm32f10x.c \
                  drivers/gpio_stm32f10x.c \
                  drivers/adc.c \
                  drivers/adc_stm32f10x.c \
                  drivers/bus_spi.c \
                  drivers/bus_i2c.c \
                  drivers/inverter.c 

STM32F30x_COMMON_SRC = \
                  startup_stm32f30x_md_gcc.S \
                  drivers/adc.c \
                  drivers/adc_stm32f30x.c \
                  drivers/bus_i2c.c \
                  drivers/bus_i2c_stm32f30x.c \
                  drivers/bus_spi.c \
                  drivers/gpio_stm32f30x.c \
                  drivers/inverter.c \
                  drivers/light_led.c \
                  drivers/light_ws2811strip.c \
                  drivers/light_ws2811strip_stm32f30x.c \
                  drivers/pwm_mapping.c \
                  drivers/pwm_output.c \
                  drivers/pwm_rx.c \
                  drivers/serial_softserial.c \
                  drivers/serial_uart.c \
                  drivers/serial_uart_stm32f30x.c \
                  drivers/sound_beeper.c \
                  drivers/system_stm32f30x.c \
                  drivers/timer.c \
                  drivers/timer_stm32f30x.c \
                  drivers/dma.c

STM32F4xx_COMMON_SRC = \
                   startup_stm32f40xx.s \
                   drivers/accgyro_mpu.c \
                   drivers/adc.c \
                   drivers/adc_stm32f4xx.c \
                   drivers/bus_i2c.c \
                   drivers/bus_spi.c \
                   drivers/gpio_stm32f4xx.c \
                   drivers/inverter.c \
                   drivers/light_led.c \
                   drivers/pwm_mapping.c \
                   drivers/pwm_output.c \
                   drivers/pwm_rx.c \
                   drivers/serial_softserial.c \
                   drivers/serial_uart.c \
                   drivers/serial_uart_stm32f4xx.c \
                   drivers/sound_beeper.c \
                   drivers/system_stm32f4xx.c \
                   drivers/timer.c \
                   drivers/timer_stm32f4xx.c \
                   drivers/flash_m25p16.c \
                   io/flashfs.c \
		   drivers/dma_stm32f4xx.c

VCP_SRC = \
		   vcp/hw_config.c \
		   vcp/stm32_it.c \
		   vcp/usb_desc.c \
		   vcp/usb_endp.c \
		   vcp/usb_istr.c \
		   vcp/usb_prop.c \
		   vcp/usb_pwr.c \
		   drivers/serial_usb_vcp.c \
		   drivers/usb_io.c

VCPF4_SRC       = \
                   vcpf4/stm32f4xx_it.c \
                   vcpf4/usb_bsp.c \
                   vcpf4/usbd_desc.c \
                   vcpf4/usbd_usr.c \
                   vcpf4/usbd_cdc_vcp.c \
                   drivers/serial_usb_vcp.c

NAZE_SRC = $(STM32F10x_COMMON_SRC) \
		   drivers/accgyro_adxl345.c \
		   drivers/accgyro_bma280.c \
		   drivers/accgyro_l3g4200d.c \
		   drivers/accgyro_mma845x.c \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu3050.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/accgyro_mpu6500.c \
		   drivers/accgyro_spi_mpu6500.c \
		   drivers/barometer_bmp085.c \
		   drivers/barometer_bmp280.c \
		   drivers/barometer_ms5611.c \
		   drivers/barometer_bmp280.c \
		   drivers/compass_hmc5883l.c \
		   drivers/display_ug2864hsweg01.h \
		   drivers/flash_m25p16.c \
		   drivers/light_led.c \
		   drivers/light_ws2811strip.c \
		   drivers/light_ws2811strip_stm32f10x.c \
		   drivers/sonar_hcsr04.c \
		   drivers/sound_beeper.c \
		   io/flashfs.c \
		   hardware_revision.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC)

ALIENFLIGHTF1_SRC = $(NAZE_SRC)

AFROMINI_SRC = $(NAZE_SRC)

EUSTM32F103RC_SRC = $(STM32F10x_COMMON_SRC) \
		   drivers/accgyro_adxl345.c \
		   drivers/accgyro_bma280.c \
		   drivers/accgyro_l3g4200d.c \
		   drivers/accgyro_mma845x.c \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu3050.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/accgyro_spi_mpu6000.c \
		   drivers/accgyro_spi_mpu6500.c \
		   drivers/barometer_bmp085.c \
		   drivers/barometer_bmp280.c \
		   drivers/barometer_ms5611.c \
		   drivers/compass_ak8975.c \
		   drivers/compass_hmc5883l.c \
		   drivers/display_ug2864hsweg01.c \
		   drivers/flash_m25p16.c \
		   drivers/light_led.c \
		   drivers/light_ws2811strip.c \
		   drivers/light_ws2811strip_stm32f10x.c \
		   drivers/sonar_hcsr04.c \
		   drivers/sound_beeper.c \
		   io/flashfs.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC)

PORT103R_SRC = $(EUSTM32F103RC_SRC)

OLIMEXINO_SRC = $(STM32F10x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/barometer_bmp085.c \
		   drivers/barometer_bmp280.c \
		   drivers/compass_hmc5883l.c \
		   drivers/light_led.c \
		   drivers/light_ws2811strip.c \
		   drivers/light_ws2811strip_stm32f10x.c \
		   drivers/sonar_hcsr04.c \
		   drivers/sound_beeper.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC)

CJMCU_SRC = $(STM32F10x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/compass_hmc5883l.c \
		   drivers/light_led.c \
		   drivers/sound_beeper.c \
		   hardware_revision.c \
		   blackbox/blackbox.c \
		   blackbox/blackbox_io.c \
		   $(COMMON_SRC)

CC3D_SRC = $(STM32F10x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_spi_mpu6000.c \
		   drivers/barometer_bmp085.c \
		   drivers/barometer_bmp280.c \
		   drivers/barometer_ms5611.c \
		   drivers/compass_hmc5883l.c \
		   drivers/display_ug2864hsweg01.c \
		   drivers/flash_m25p16.c \
		   drivers/light_led.c \
		   drivers/light_ws2811strip.c \
		   drivers/light_ws2811strip_stm32f10x.c \
		   drivers/sonar_hcsr04.c \
		   drivers/sound_beeper.c \
		   io/flashfs.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)

REVO_SRC = $(STM32F4xx_COMMON_SRC) \
                  drivers/accgyro_spi_mpu6000.c \
                  drivers/barometer_ms5611.c \
                  drivers/compass_hmc5883l.c \
                  drivers/light_ws2811strip.c \
                  drivers/light_ws2811strip_stm32f4xx.c \
                  $(HIGHEND_SRC) \
                  $(COMMON_SRC) \
                  $(VCPF4_SRC)

REVONANO_SRC = $(STM32F4xx_COMMON_SRC) \
                  drivers/accgyro_spi_mpu9250.c \
                  drivers/barometer_ms5611.c \
                  drivers/compass_hmc5883l.c \
                  $(HIGHEND_SRC) \
                  $(COMMON_SRC) \
                  $(VCPF4_SRC)

SPARKY2_SRC = $(STM32F4xx_COMMON_SRC) \
                  drivers/accgyro_spi_mpu9250.c \
                  drivers/barometer_ms5611.c \
                  drivers/compass_ak8963.c \
                  drivers/light_ws2811strip.c \
                  drivers/light_ws2811strip_stm32f4xx.c \
                  $(HIGHEND_SRC) \
                  $(COMMON_SRC) \
                  $(VCPF4_SRC)

ALIENFLIGHTF4_SRC = $(STM32F4xx_COMMON_SRC) \
		  drivers/accgyro_mpu6500.c \
		  drivers/accgyro_spi_mpu6500.c \
                  drivers/accgyro_spi_mpu9250.c \
                  drivers/barometer_bmp280.c \
                  drivers/barometer_ms5611.c \
                  drivers/compass_ak8963.c \
                  drivers/compass_hmc5883l.c \
                  drivers/light_ws2811strip.c \
                  drivers/light_ws2811strip_stm32f4xx.c \
                  drivers/sdcard.c \
                  drivers/sdcard_standard.c \
                  io/asyncfatfs/asyncfatfs.c \
                  io/asyncfatfs/fat_standard.c \
                  $(HIGHEND_SRC) \
                  $(COMMON_SRC) \
                  $(VCPF4_SRC)
                  
BLUEJAYF4_SRC = $(STM32F4xx_COMMON_SRC) \
                  drivers/accgyro_spi_mpu9250.c \
                  drivers/barometer_ms5611.c \
                  drivers/sdcard.c \
                  drivers/sdcard_standard.c \
                  io/asyncfatfs/asyncfatfs.c \
                  io/asyncfatfs/fat_standard.c \
                  $(HIGHEND_SRC) \
                  $(COMMON_SRC) \
                  $(VCPF4_SRC)

QUANTON_SRC = $(STM32F4xx_COMMON_SRC) \
                  drivers/accgyro_spi_mpu6000.c \
                  drivers/barometer_ms5611.c \
                  $(HIGHEND_SRC) \
                  $(COMMON_SRC) \
                  $(VCPF4_SRC)

AQ32_V2_SRC = $(STM32F4xx_COMMON_SRC) \
		   drivers/accgyro_spi_mpu6000.c \
		   drivers/barometer_ms5611.c \
		   drivers/compass_hmc5883l.c \
		   drivers/sdcard.c \
		   drivers/sdcard_standard.c \
		   io/asyncfatfs/asyncfatfs.c \
		   io/asyncfatfs/fat_standard.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCPF4_SRC)

VRCORE_SRC = $(STM32F4xx_COMMON_SRC) \
                  drivers/accgyro_spi_mpu9250.c \
                  drivers/barometer_ms5611.c \
                  drivers/compass_hmc5883l.c \
                  drivers/light_ws2811strip.c \
                  drivers/light_ws2811strip_stm32f4xx.c \
		  drivers/sdcard.c \
		  drivers/sdcard_standard.c \
		  io/asyncfatfs/asyncfatfs.c \
		  io/asyncfatfs/fat_standard.c \
                  $(HIGHEND_SRC) \
                  $(COMMON_SRC) \
                  $(VCPF4_SRC)

STM32F30x_COMMON_SRC += \
		   drivers/adc.c \
		   drivers/adc_stm32f30x.c \
		   drivers/bus_i2c_stm32f30x.c \
		   drivers/bus_spi.c \
		   drivers/display_ug2864hsweg01.h \
		   drivers/gpio_stm32f30x.c \
		   drivers/light_led_stm32f30x.c \
		   drivers/pwm_mapping.c \
		   drivers/pwm_output.c \
		   drivers/pwm_rx.c \
		   drivers/serial_uart.c \
		   drivers/serial_uart_stm32f30x.c \
		   drivers/sound_beeper_stm32f30x.c \
		   drivers/system_stm32f30x.c \
		   drivers/timer.c \
		   drivers/timer_stm32f30x.c

NAZE32PRO_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)

STM32F3DISCOVERY_COMMON_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/light_ws2811strip.c \
		   drivers/accgyro_l3gd20.c \
		   drivers/accgyro_lsm303dlhc.c \
		   drivers/compass_hmc5883l.c \
		   $(VCP_SRC)

STM32F3DISCOVERY_SRC = \
		   $(STM32F3DISCOVERY_COMMON_SRC) \
		   drivers/accgyro_adxl345.c \
		   drivers/accgyro_bma280.c \
		   drivers/accgyro_mma845x.c \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu3050.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/accgyro_l3g4200d.c \
		   drivers/barometer_ms5611.c \
		   drivers/barometer_bmp280.c \
		   drivers/compass_ak8975.c \
		   drivers/sdcard.c \
		   drivers/sdcard_standard.c \
		   io/asyncfatfs/asyncfatfs.c \
		   io/asyncfatfs/fat_standard.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC)

CHEBUZZF3_SRC = \
		   $(STM32F3DISCOVERY_SRC) \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC)

COLIBRI_RACE_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   io/i2c_bst.c \
		   drivers/bus_bst_stm32f30x.c \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6500.c \
		   drivers/accgyro_spi_mpu6000.c \
		   drivers/accgyro_spi_mpu6500.c \
		   drivers/accgyro_mpu6500.c \
		   drivers/barometer_ms5611.c \
		   drivers/compass_ak8963.c \
		   drivers/compass_ak8975.c \
		   drivers/compass_hmc5883l.c \
		   drivers/display_ug2864hsweg01.c \
		   drivers/light_ws2811strip.c \
		   drivers/light_ws2811strip_stm32f30x.c \
		   drivers/serial_usb_vcp.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)

LUX_RACE_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6500.c \
		   drivers/accgyro_spi_mpu6500.c \
		   drivers/accgyro_mpu6500.c \
		   drivers/light_ws2811strip.c \
		   drivers/serial_usb_vcp.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)

DOGE_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6500.c \
		   drivers/accgyro_spi_mpu6500.c \
		   drivers/barometer_bmp280.c \
		   drivers/barometer_spi_bmp280.c \
		   drivers/light_ws2811strip.c \
		   drivers/light_ws2811strip_stm32f30x.c \
		   drivers/serial_usb_vcp.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)
		   
SPARKY_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/display_ug2864hsweg01.c \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/barometer_ms5611.c \
		   drivers/barometer_bmp280.c \
		   drivers/compass_ak8975.c \
		   drivers/light_ws2811strip.c \
		   drivers/serial_usb_vcp.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)

ALIENFLIGHTF3_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6500.c \
		   drivers/accgyro_spi_mpu6500.c \
		   drivers/compass_ak8963.c \
		   hardware_revision.c \
		   drivers/serial_usb_vcp.c \
		   drivers/sonar_hcsr04.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)

RMDO_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/barometer_bmp280.c \
		   drivers/display_ug2864hsweg01.h \
		   drivers/flash_m25p16.c \
		   drivers/light_ws2811strip.c \
		   drivers/sonar_hcsr04.c \
		   io/flashfs.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC)

SPRACINGF3_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/barometer_ms5611.c \
		   drivers/compass_ak8975.c \
		   drivers/barometer_bmp085.c \
		   drivers/barometer_bmp280.c \
		   drivers/compass_hmc5883l.c \
		   drivers/display_ug2864hsweg01.h \
		   drivers/flash_m25p16.c \
		   drivers/light_ws2811strip.c \
		   drivers/sonar_hcsr04.c \
		   io/flashfs.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC)
		   
IRCFUSIONF3_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/barometer_bmp085.c \
		   drivers/flash_m25p16.c \
		   io/flashfs.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC)

SPRACINGF3EVO_SRC	 = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6500.c \
		   drivers/accgyro_spi_mpu6500.c \
		   drivers/barometer_bmp280.c \
		   drivers/compass_ak8963.c \
		   drivers/display_ug2864hsweg01.h \
		   drivers/light_ws2811strip.c \
		   drivers/light_ws2811strip_stm32f30x.c \
		   drivers/serial_usb_vcp.c \
		   drivers/sdcard.c \
		   drivers/sdcard_standard.c \
		   drivers/transponder_ir.c \
		   drivers/transponder_ir_stm32f30x.c \
		   io/asyncfatfs/asyncfatfs.c \
		   io/asyncfatfs/fat_standard.c \
		   io/transponder_ir.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)

MOTOLAB_SRC = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/display_ug2864hsweg01.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/accgyro_spi_mpu6000.c \
		   drivers/barometer_ms5611.c \
		   drivers/compass_hmc5883l.c \
		   drivers/light_ws2811strip.c \
		   drivers/serial_usb_vcp.c \
		   drivers/flash_m25p16.c \
		   io/flashfs.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)

SPRACINGF3MINI_SRC	 = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6500.c \
		   drivers/barometer_bmp280.c \
		   drivers/compass_ak8975.c \
		   drivers/compass_hmc5883l.c \
		   drivers/display_ug2864hsweg01.h \
		   drivers/flash_m25p16.c \
		   drivers/light_ws2811strip.c \
		   drivers/serial_usb_vcp.c \
		   drivers/sonar_hcsr04.c \
		   drivers/sdcard.c \
		   drivers/sdcard_standard.c \
		   drivers/transponder_ir.c \
		   drivers/transponder_ir_stm32f30x.c \
		   io/asyncfatfs/asyncfatfs.c \
		   io/asyncfatfs/fat_standard.c \
		   io/transponder_ir.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)
#		   $(FATFS_SRC)

SINGULARITY_SRC	 = \
		   $(STM32F30x_COMMON_SRC) \
		   drivers/accgyro_mpu.c \
		   drivers/accgyro_mpu6050.c \
		   drivers/flash_m25p16.c \
		   drivers/light_ws2811strip.c \
		   drivers/light_ws2811strip_stm32f30x.c \
		   drivers/serial_softserial.c \
		   drivers/serial_usb_vcp.c \
		   drivers/vtx_rtc6705.c \
		   io/flashfs.c \
		   io/vtx.c \
		   $(HIGHEND_SRC) \
		   $(COMMON_SRC) \
		   $(VCP_SRC)

# Search path and source files for the ST stdperiph library
VPATH		:= $(VPATH):$(STDPERIPH_DIR)/src

###############################################################################
# Things that might need changing to use different tools
#

# Tool names
CC		 = arm-none-eabi-gcc
OBJCOPY		 = arm-none-eabi-objcopy
SIZE		 = arm-none-eabi-size

#
# Tool options.
#

ifeq ($(DEBUG),GDB)
OPTIMIZE	 = -O0
LTO_FLAGS	 = $(OPTIMIZE)
else
ifeq ($(TARGET),$(filter $(TARGET),SPARKY2 SPARKY2_OPBL))
OPTIMIZE        = -O0
else ifeq ($(TARGET),$(filter $(TARGET),REVO REVO_OPBL REVONANO REVONANO_OPBL ALIENFLIGHTF4 BLUEJAYF4 VRCORE AQ32_V2))
OPTIMIZE        = -O2
else
OPTIMIZE	 = -Os
endif
LTO_FLAGS	 = -flto -fuse-linker-plugin $(OPTIMIZE)
endif

DEBUG_FLAGS	 = -ggdb3 -DDEBUG

CFLAGS		 += $(ARCH_FLAGS) \
		   $(LTO_FLAGS) \
		   $(addprefix -D,$(OPTIONS)) \
		   $(addprefix -I,$(INCLUDE_DIRS)) \
		   $(DEBUG_FLAGS) \
		   -std=gnu99 \
		   -Wall -Wextra -Wunsafe-loop-optimizations -Wdouble-promotion \
		   -ffunction-sections \
		   -fdata-sections \
		   $(DEVICE_FLAGS) \
		   -DUSE_STDPERIPH_DRIVER \
		   $(TARGET_FLAGS) \
		   -D'__FORKNAME__="$(FORKNAME)"' \
		   -D'__TARGET__="$(TARGET)"' \
		   -D'__REVISION__="$(REVISION)"' \
		   -save-temps=obj \
		   -MMD -MP

ASFLAGS		 = $(ARCH_FLAGS) \
		   -x assembler-with-cpp \
		   $(addprefix -I,$(INCLUDE_DIRS)) \
		  -MMD -MP

LDFLAGS		 = -lm \
		   -nostartfiles \
		   --specs=nano.specs \
		   -lc \
		   -lnosys \
		   $(ARCH_FLAGS) \
		   $(LTO_FLAGS) \
		   $(DEBUG_FLAGS) \
		   -static \
		   -Wl,-gc-sections,-Map,$(TARGET_MAP) \
		   -Wl,-L$(LINKER_DIR) \
           -Wl,--cref \
		   -T$(LD_SCRIPT)

###############################################################################
# No user-serviceable parts below
###############################################################################

CPPCHECK         = cppcheck $(CSOURCES) --enable=all --platform=unix64 \
		   --std=c99 --inline-suppr --quiet --force \
		   $(addprefix -I,$(INCLUDE_DIRS)) \
		   -I/usr/include -I/usr/include/linux

#
# Things we will build
#
ifeq ($(filter $(TARGET),$(VALID_TARGETS)),)
$(error Target '$(TARGET)' is not valid, must be one of $(VALID_TARGETS))
endif

CC3D_OPBL_SRC     = $(CC3D_SRC)
REVO_OPBL_SRC     = $(REVO_SRC)
REVONANO_OPBL_SRC = $(REVONANO_SRC)
SPARKY2_OPBL_SRC  = $(SPARKY2_SRC)
QUANTON_OPBL_SRC  = $(QUANTON_SRC)

TARGET_BIN	 = $(BIN_DIR)/$(FORKNAME)_$(FC_VER)_$(TARGET).bin
TARGET_HEX	 = $(BIN_DIR)/$(FORKNAME)_$(FC_VER)_$(TARGET).hex
TARGET_ELF	 = $(OBJECT_DIR)/$(FORKNAME)_$(TARGET).elf
TARGET_OBJS	 = $(addsuffix .o,$(addprefix $(OBJECT_DIR)/$(TARGET)/,$(basename $($(TARGET)_SRC))))
TARGET_DEPS	 = $(addsuffix .d,$(addprefix $(OBJECT_DIR)/$(TARGET)/,$(basename $($(TARGET)_SRC))))
TARGET_MAP	 = $(OBJECT_DIR)/$(FORKNAME)_$(TARGET).map

CLEAN_ARTIFACTS := $(TARGET_BIN)
CLEAN_ARTIFACTS += $(TARGET_HEX)
CLEAN_ARTIFACTS += $(TARGET_ELF) $(TARGET_OBJS) $(TARGET_MAP) 

# List of buildable ELF files and their object dependencies.
# It would be nice to compute these lists, but that seems to be just beyond make.

$(TARGET_HEX): $(TARGET_ELF)
	$(OBJCOPY) -O ihex --set-start 0x8000000 $< $@

$(TARGET_BIN): $(TARGET_ELF)
	$(OBJCOPY) -O binary $< $@

$(TARGET_ELF):  $(TARGET_OBJS)
	@echo LD $(notdir $@)
	@$(CC) -o $@ $^ $(LDFLAGS)
	$(SIZE) $(TARGET_ELF) 

# Compile
$(OBJECT_DIR)/$(TARGET)/%.o: %.c
	@mkdir -p $(dir $@)
	@echo %% $(notdir $<)
	@$(CC) -c -o $@ $(CFLAGS) $<

# Assemble
$(OBJECT_DIR)/$(TARGET)/%.o: %.s
	@mkdir -p $(dir $@)
	@echo %% $(notdir $<)
	@$(CC) -c -o $@ $(ASFLAGS) $<

$(OBJECT_DIR)/$(TARGET)/%.o: %.S
	@mkdir -p $(dir $@)
	@echo %% $(notdir $<)
	@$(CC) -c -o $@ $(ASFLAGS) $<


## all         : default task; compile C code, build firmware
all: binary

## clean       : clean up all temporary / machine-generated files
clean:
	rm -f $(CLEAN_ARTIFACTS)
	rm -rf $(OBJECT_DIR)/$(TARGET)
	cd src/test && $(MAKE) clean || true

flash_$(TARGET): $(TARGET_HEX)
	stty -F $(SERIAL_DEVICE) raw speed 115200 -crtscts cs8 -parenb -cstopb -ixon
	echo -n 'R' >$(SERIAL_DEVICE)
	stm32flash -w $(TARGET_HEX) -v -g 0x0 -b 115200 $(SERIAL_DEVICE)

## flash       : flash firmware (.hex) onto flight controller
flash: flash_$(TARGET)

st-flash_$(TARGET): $(TARGET_BIN)
	st-flash --reset write $< 0x08000000

## st-flash    : flash firmware (.bin) onto flight controller
st-flash: st-flash_$(TARGET)

binary: $(TARGET_BIN)
hex:    $(TARGET_HEX)

unbrick_$(TARGET): $(TARGET_HEX)
	stty -F $(SERIAL_DEVICE) raw speed 115200 -crtscts cs8 -parenb -cstopb -ixon
	stm32flash -w $(TARGET_HEX) -v -g 0x0 -b 115200 $(SERIAL_DEVICE)

## unbrick     : unbrick flight controller
unbrick: unbrick_$(TARGET)

## cppcheck    : run static analysis on C source code
cppcheck: $(CSOURCES)
	$(CPPCHECK)

cppcheck-result.xml: $(CSOURCES)
	$(CPPCHECK) --xml-version=2 2> cppcheck-result.xml

## help        : print this help message and exit
help: Makefile
	@echo ""
	@echo "Makefile for the $(FORKNAME) firmware"
	@echo ""
	@echo "Usage:"
	@echo "        make [TARGET=<target>] [OPTIONS=\"<options>\"]"
	@echo ""
	@echo "Valid TARGET values are: $(VALID_TARGETS)"
	@echo ""
	@sed -n 's/^## //p' $<

## test        : run the cleanflight test suite
test:
	cd src/test && $(MAKE) test || true

# rebuild everything when makefile changes
$(TARGET_OBJS) : Makefile

# include auto-generated dependencies
-include $(TARGET_DEPS)
