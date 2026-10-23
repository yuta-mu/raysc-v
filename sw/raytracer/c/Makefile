HOST_CC ?= gcc
RISCV_CC ?= riscv64-unknown-elf-gcc
RISCV_SIZE ?= riscv64-unknown-elf-size
RISCV_ARCH ?= rv32i
RISCV_ABI ?= ilp32
BSP_DIR ?= ../../../bsp
UART_DIR ?= riscv/bsp/qemu
BUILD_DIR ?= build
MODE ?= mirrors
SIZE ?= baseline
SCENE ?= baseline
SEED ?= 20261023
SUBPIXELS ?= 4

size_width_baseline := 64
size_height_baseline := 36
size_width_micro := 32
size_height_micro := 18
size_width_tiny := 80
size_height_tiny := 45
size_width_full := 160
size_height_full := 90
ifeq ($(filter $(SIZE),baseline micro tiny full),)
$(error SIZE must be baseline, micro, tiny or full)
endif
WIDTH ?= $(size_width_$(SIZE))
HEIGHT ?= $(size_height_$(SIZE))

CPPFLAGS ?=
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Werror -pedantic -ffunction-sections -fdata-sections -fstack-usage
LDFLAGS ?=

mode_flags_normals := -DRENDER_NORMALS=1 -DRENDER_MIRRORS=0
mode_flags_lit := -DRENDER_MIRRORS=0 -DRENDER_SHADOWS=0
mode_flags_shadowed := -DRENDER_MIRRORS=0
mode_flags_mirrors :=
ifeq ($(filter $(MODE),normals lit shadowed mirrors),)
$(error MODE must be normals, lit, shadowed or mirrors)
endif

core_sources := core/render.c fpm.c
scene_flags :=
scene_suffix :=
ifeq ($(SCENE),random)
core_sources := core/render_random.c fpm.c
scene_flags := -DRENDER_SEED=$(SEED)u -DRENDER_SUBPIXELS=$(SUBPIXELS)
scene_suffix := /random-$(SEED)-$(SUBPIXELS)x$(SUBPIXELS)
else ifneq ($(SCENE),baseline)
$(error SCENE must be baseline or random)
endif
core_headers := fpm.h qmath.h ref/qmath.h $(wildcard core/*.h)
image_flags := -DRENDER_WIDTH=$(WIDTH) -DRENDER_HEIGHT=$(HEIGHT)
image_suffix := /$(WIDTH)x$(HEIGHT)
ifeq ($(WIDTH)x$(HEIGHT),64x36)
image_suffix :=
endif
host_binary := $(BUILD_DIR)/host/$(MODE)$(scene_suffix)$(image_suffix)/raytracer
riscv_binary := $(BUILD_DIR)/riscv/$(MODE)$(scene_suffix)$(image_suffix)/raytracer.elf

.PHONY: all host image riscv size-host size-riscv golden golden-candidate test

all: host

host: $(host_binary)

$(host_binary): $(core_sources) $(core_headers) host/main.c host/output.c Makefile
	mkdir -p $(dir $@)
	$(HOST_CC) $(CPPFLAGS) $(mode_flags_$(MODE)) $(image_flags) $(scene_flags) $(CFLAGS) $(core_sources) host/main.c host/output.c $(LDFLAGS) -Wl,--gc-sections,-Map,$@.map -o $@

image: host
	$(host_binary) > $(host_binary).ppm

riscv: $(riscv_binary)

$(riscv_binary): $(core_sources) $(core_headers) riscv/main.c riscv/output.c $(UART_DIR)/uart.h $(BSP_DIR)/crt0.s $(BSP_DIR)/linker.ld Makefile
	mkdir -p $(dir $@)
	$(RISCV_CC) $(CPPFLAGS) $(mode_flags_$(MODE)) $(image_flags) $(scene_flags) $(CFLAGS) -march=$(RISCV_ARCH) -mabi=$(RISCV_ABI) -ffreestanding -fno-builtin -msmall-data-limit=0 -mno-relax -nostdlib -nostartfiles -I$(UART_DIR) $(BSP_DIR)/crt0.s $(core_sources) riscv/main.c riscv/output.c $(LDFLAGS) -T$(BSP_DIR)/linker.ld -Wl,--no-relax,--gc-sections,-Map,$@.map -lgcc -o $@

size-host: host
	size $(host_binary)

size-riscv: riscv
	$(RISCV_SIZE) $(riscv_binary)

golden:
	python3 tools/golden.py --build-dir "$(BUILD_DIR)/golden"

golden-candidate:
	python3 tools/golden.py --build-dir "$(BUILD_DIR)/golden-candidate" --candidate-dir "$(OUTPUT_DIR)"

test:
	bash tests/run_c04.sh
