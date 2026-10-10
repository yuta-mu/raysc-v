# Out-of-tree OCaml compiler build. The executable is named rayqc (not simc).
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
SHELL := /bin/sh

BUILD_DIR ?= ../build/compiler
BUILD_DIR := $(abspath $(BUILD_DIR))
OCAMLC    ?= ocamlc
OCAMLLEX  ?= ocamllex
OCAMLYACC ?= ocamlyacc

.PHONY: all clean
all: $(BUILD_DIR)/rayqc

$(BUILD_DIR)/:
	@mkdir -p "$@"

# ocamlyacc emits parser.ml and parser.mli into BUILD_DIR.
$(BUILD_DIR)/parser.stamp: parser.mly | $(BUILD_DIR)/
	$(OCAMLYACC) -b $(BUILD_DIR)/parser parser.mly
	@touch "$@"

$(BUILD_DIR)/parser.ml $(BUILD_DIR)/parser.mli: $(BUILD_DIR)/parser.stamp
	@test -f "$@" || { $(OCAMLYACC) -b $(BUILD_DIR)/parser parser.mly; touch "$(BUILD_DIR)/parser.stamp"; }

$(BUILD_DIR)/ast.cmo: ast.ml | $(BUILD_DIR)/
	$(OCAMLC) -c -o "$@" "$<"

$(BUILD_DIR)/parser.cmi: $(BUILD_DIR)/parser.mli $(BUILD_DIR)/ast.cmo
	$(OCAMLC) -I "$(BUILD_DIR)" -c -o "$@" "$(BUILD_DIR)/parser.mli"

$(BUILD_DIR)/lexer.ml: lexer.mll $(BUILD_DIR)/parser.mli | $(BUILD_DIR)/
	$(OCAMLLEX) -o "$@" lexer.mll

$(BUILD_DIR)/lexer.cmo: $(BUILD_DIR)/lexer.ml $(BUILD_DIR)/parser.cmi
	$(OCAMLC) -I "$(BUILD_DIR)" -c -o "$@" "$<"

$(BUILD_DIR)/parser.cmo: $(BUILD_DIR)/parser.ml $(BUILD_DIR)/parser.cmi $(BUILD_DIR)/ast.cmo
	$(OCAMLC) -I "$(BUILD_DIR)" -c -o "$@" "$(BUILD_DIR)/parser.ml"

$(BUILD_DIR)/types.cmo: types.ml | $(BUILD_DIR)/
	$(OCAMLC) -c -o "$@" "$<"

$(BUILD_DIR)/table.cmo: table.ml $(BUILD_DIR)/types.cmo
	$(OCAMLC) -I "$(BUILD_DIR)" -c -o "$@" "$<"

$(BUILD_DIR)/semant.cmo: semant.ml $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/types.cmo $(BUILD_DIR)/table.cmo
	$(OCAMLC) -I "$(BUILD_DIR)" -c -o "$@" "$<"

$(BUILD_DIR)/emitter.cmo: emitter.ml $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/types.cmo $(BUILD_DIR)/table.cmo $(BUILD_DIR)/semant.cmo
	$(OCAMLC) -I "$(BUILD_DIR)" -c -o "$@" "$<"

$(BUILD_DIR)/rayqc.cmo: rayqc.ml $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/emitter.cmo
	$(OCAMLC) -I "$(BUILD_DIR)" -c -o "$@" "$<"

$(BUILD_DIR)/rayqc: $(BUILD_DIR)/ast.cmo $(BUILD_DIR)/parser.cmo $(BUILD_DIR)/lexer.cmo \
                    $(BUILD_DIR)/types.cmo $(BUILD_DIR)/table.cmo $(BUILD_DIR)/semant.cmo \
                    $(BUILD_DIR)/emitter.cmo $(BUILD_DIR)/rayqc.cmo
	$(OCAMLC) -I "$(BUILD_DIR)" -o "$@" unix.cma \
		$(BUILD_DIR)/ast.cmo $(BUILD_DIR)/lexer.cmo $(BUILD_DIR)/parser.cmo \
		$(BUILD_DIR)/types.cmo $(BUILD_DIR)/table.cmo $(BUILD_DIR)/semant.cmo \
		$(BUILD_DIR)/emitter.cmo $(BUILD_DIR)/rayqc.cmo

clean:
	rm -rf "$(BUILD_DIR)"
