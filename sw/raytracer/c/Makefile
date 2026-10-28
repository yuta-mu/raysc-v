HOST_CC ?= gcc
RISCV_CC ?= riscv64-unknown-elf-gcc
RISCV_SIZE ?= riscv64-unknown-elf-size
RISCV_ARCH ?= $(if $(filter weekend,$(MODE)),rv32im,rv32i)
RISCV_ABI ?= ilp32
BSP_DIR ?= ../../../bsp
UART_DIR ?= riscv/bsp/qemu
BUILD_DIR ?= build
MODE ?= mirrors
SIZE ?= baseline
SCENE ?= baseline
SEED ?= 20261023
SUBPIXELS ?= 4
PROFILE ?= connect
SAMPLES ?= $(if $(filter production,$(PROFILE)),500,$(if $(filter quality,$(PROFILE)),100,10))
MAX_DEPTH ?= $(if $(filter production,$(PROFILE)),50,$(if $(filter quality,$(PROFILE)),20,5))
DEFOCUS ?= 39322
GAMMA ?= 1

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
ifeq ($(MODE),weekend)
ifeq ($(filter $(PROFILE),connect quality production),)
$(error PROFILE must be connect, quality or production)
endif
WIDTH ?= $(if $(filter production,$(PROFILE)),1200,$(if $(filter quality,$(PROFILE)),320,64))
HEIGHT ?= $(if $(filter production,$(PROFILE)),900,$(if $(filter quality,$(PROFILE)),240,48))
else
WIDTH ?= $(size_width_$(SIZE))
HEIGHT ?= $(size_height_$(SIZE))
endif

CPPFLAGS ?=
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Werror -pedantic -ffunction-sections -fdata-sections -fstack-usage
LDFLAGS ?=

mode_flags_normals := -DRENDER_NORMALS=1 -DRENDER_MIRRORS=0
mode_flags_lit := -DRENDER_MIRRORS=0 -DRENDER_SHADOWS=0
mode_flags_shadowed := -DRENDER_MIRRORS=0
mode_flags_mirrors :=
mode_flags_weekend := -DRENDER_GAMMA2=$(GAMMA)
ifeq ($(filter $(MODE),normals lit shadowed mirrors weekend),)
$(error MODE must be normals, lit, shadowed, mirrors or weekend)
endif

core_sources := core/render.c fpm.c
scene_flags :=
scene_suffix :=
ifeq ($(MODE),weekend)
ifeq ($(filter $(GAMMA),0 1),)
$(error GAMMA must be 0 or 1)
endif
core_sources := core/render_weekend.c fpm.c
scene_flags := -DRENDER_SEED=$(SEED)u -DRENDER_SAMPLES=$(SAMPLES) -DRENDER_DEPTH=$(MAX_DEPTH) -DRENDER_DEFOCUS=$(DEFOCUS)
scene_suffix := /$(SEED)-$(SAMPLES)spp-$(MAX_DEPTH)depth-$(DEFOCUS)defocus-$(GAMMA)gamma
else ifeq ($(SCENE),random)
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
riscv_isa_suffix := $(if $(filter weekend,$(MODE)),/$(RISCV_ARCH)-$(RISCV_ABI))
riscv_binary := $(BUILD_DIR)/riscv/$(MODE)$(riscv_isa_suffix)$(scene_suffix)$(image_suffix)/raytracer.elf
weekend_cli := $(BUILD_DIR)/host/weekend-cli/$(GAMMA)gamma/raytracer

.PHONY: all host image riscv size-host size-riscv golden golden-candidate test test-final profile weekend weekend-cli

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

test-final:
	bash tests/run_rt_test01.sh

profile:
	python3 tools/profile/launch.py

weekend:
	$(MAKE) MODE=weekend host

weekend-cli: $(weekend_cli)

$(weekend_cli): host/weekend.c host/output.c fpm.c $(core_headers) Makefile
	mkdir -p $(dir $@)
	$(HOST_CC) $(CPPFLAGS) -DRENDER_GAMMA2=$(GAMMA) $(CFLAGS) host/weekend.c fpm.c host/output.c $(LDFLAGS) -Wl,--gc-sections,-Map,$@.map -o $@
