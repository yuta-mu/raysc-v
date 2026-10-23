CXX ?= g++
CPPFLAGS ?=
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra

core_headers := $(wildcard core/*.h) fpm.h
legacy_headers := $(wildcard legacy/*.h) fpm.h
legacy_programs := main ppm week1 week2
legacy_binaries := $(addprefix build/legacy/,$(legacy_programs))

.PHONY: all legacy test

all: build/current/raytracer

build/current/raytracer: core/main.cpp fpm.cpp $(core_headers) | build/current
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) core/main.cpp fpm.cpp -o $@

legacy: $(legacy_binaries)

build/legacy/%: legacy/%.cpp fpm.cpp $(legacy_headers) | build/legacy
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< fpm.cpp -o $@

build/current build/legacy:
	mkdir -p $@

test:
	bash tests/run_cpp01.sh
	bash tests/run_cpp07.sh
