# RISC-V ISA Tests for RaySC-V

The test programs in `hex/` are derived from the official [riscv-tests](https://github.com/riscv-software-src/riscv-tests) repository, licensed under the BSD 3-Clause License (see `LICENSE.riscv-tests`).

### Modifications for RaySC-V
- Relocated base address to `0x0000_0000`.
- Modified test completion to execute `ebreak` instead of writing to `tohost`.
- Pre-compiled into 32-bit hex files for direct simulation with Icarus Verilog (`$readmemh`).

### Covered Tests (48 tests)
- **RV32UI** (40 tests): Basic integer instructions.
  - *Excluded*: `fence_i` (no instruction cache), `ma_data` (strict 4-byte alignment architecture).
- **RV32UM** (8 tests): Hardware multiplication and division.

### How to Run
```bash
python3 run_all_tests.py
```

