BUILD_DIR ?= ../build/compiler
TARGET    := $(BUILD_DIR)/rayqc

ML_SRCS := ast.ml numeric.ml semant.ml ir.ml translate.ml emitter.ml main.ml

all: $(TARGET)

$(BUILD_DIR)/parser.ml $(BUILD_DIR)/parser.mli: parser.mly
	@mkdir -p $(BUILD_DIR)
	ocamlyacc -b $(BUILD_DIR)/parser parser.mly

$(BUILD_DIR)/lexer.ml: lexer.mll $(BUILD_DIR)/parser.mli
	@mkdir -p $(BUILD_DIR)
	ocamllex -o $(BUILD_DIR)/lexer.ml lexer.mll

$(TARGET): $(BUILD_DIR)/parser.ml $(BUILD_DIR)/lexer.ml $(ML_SRCS)
	@mkdir -p $(BUILD_DIR)
	cp $(ML_SRCS) $(BUILD_DIR)/
	cd $(BUILD_DIR) && ocamlopt -I . -o rayqc \
		ast.ml numeric.ml parser.mli parser.ml lexer.ml semant.ml ir.ml translate.ml emitter.ml main.ml

clean:
	rm -rf $(BUILD_DIR)
