FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git curl wget make ca-certificates sudo locales \
    gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf \
    qemu-system-misc gdb-multiarch \
    verilator iverilog gtkwave \
    ocaml-nox vim python3\
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu
RUN mkdir -p /workspace && chown ubuntu:ubuntu /workspace

USER ubuntu
WORKDIR /workspace
SHELL ["/bin/bash", "-c"]
CMD ["/bin/bash"]
