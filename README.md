# Computer Architecture Labs

Verilog implementations and experiments for a progressively more advanced
RISC-V processor design flow. The repository starts from arithmetic building
blocks, then builds pipelined processors, scoreboard-based issue logic,
out-of-order execution support, and cache hierarchy variants.

## Overview

This project is organized as a set of computer architecture labs. Each lab
focuses on one layer of a CPU design:

- functional hardware blocks such as integer multiply/divide units
- RISC-V datapath and control implementation
- pipeline hazards, bypassing, and stalling
- scoreboard-driven issue control
- reorder-buffer-based out-of-order execution
- cache wrappers, cache FSMs, and victim-cache behavior

The code is written primarily in Verilog, with RISC-V assembly tests and small
benchmark programs used to validate behavior through simulation.

## Lab Roadmap

| Lab | Focus | Main directories | What it demonstrates |
| --- | --- | --- | --- |
| Lab 1 | Integer multiply/divide hardware | `lab1/imuldiv`, `lab1/vc` | Iterative and single-cycle arithmetic units, Booth multiplication, test harnesses, and reusable Verilog components. |
| Lab 2 | Baseline pipelined RISC-V cores | `lab2/riscvlong`, `lab2/riscvstall`, `lab2/riscvbyp` | A long-latency baseline, a stall-based pipeline, and a bypassing pipeline for data-hazard handling. |
| Lab 3 | Scoreboard and dual-fetch exploration | `lab3/riscvdualfetch`, `lab3/riscvssc` | Dual-fetch control paths and scoreboard-based dependency tracking for more aggressive issue behavior. |
| Lab 4 | Out-of-order execution | `lab4/riscvooo`, `lab4/riscvlong` | Reorder buffer and scoreboard structures for preserving correct architectural state while allowing out-of-order progress. |
| Lab 5 | Cache hierarchy experiments | `lab5/riscvbc`, `lab5/riscvlong` | Cache wrappers, I-cache/D-cache configurations, bypass/no-cache modes, and a more complete D-cache with victim-cache behavior. |

## Repository Layout

```text
.
|-- lab1/
|   |-- imuldiv/      # Integer multiplier/divider RTL and tests
|   `-- vc/           # Reusable Verilog components and test utilities
|-- lab2/
|   |-- riscvlong/    # Baseline RISC-V core
|   |-- riscvstall/   # Stall-based pipeline
|   |-- riscvbyp/     # Bypassing pipeline
|   |-- tests/        # RISC-V assembly tests
|   `-- ubmark/       # Small C benchmarks
|-- lab3/
|   |-- riscvdualfetch/
|   |-- riscvssc/     # Scoreboard-based core variant
|   |-- tests/
|   `-- ubmark/
|-- lab4/
|   |-- riscvlong/
|   |-- riscvooo/     # Out-of-order core with ROB/scoreboard structures
|   |-- tests/
|   `-- ubmark/
|-- lab5/
|   |-- riscvlong/
|   |-- riscvbc/      # Cache hierarchy variants
|   |-- tests/
|   `-- ubmark/
|-- Source/           # Original lab source archives
`-- Submitted/        # Local submission artifacts, ignored by Git
```

Generated build products live under `build/` directories and are intentionally
ignored by Git.

## Architecture Highlights

### Arithmetic Units

Lab 1 implements and tests several integer multiply/divide designs:

- iterative multiplier and divider
- combined iterative multiply/divide unit
- single-cycle multiply/divide unit
- Booth multiplier
- three-input multiplier request/response path

These units are reused by later RISC-V cores through the `imuldiv` subpackage.

### RISC-V Pipeline Variants

Lab 2 introduces multiple RISC-V core variants with the same general component
shape:

- `Core.v` for top-level core integration
- `CoreCtrl.v` for pipeline/control logic
- `CoreDpath.v` for datapath structure
- `CoreDpathAlu.v` for ALU behavior
- `CoreDpathRegfile.v` for register file behavior
- `InstMsg.v` for instruction decoding fields

The three main variants compare different hazard-handling strategies:

- `riscvlong`: baseline long-latency core
- `riscvstall`: stall-based hazard handling
- `riscvbyp`: bypass/forwarding paths to reduce stalls

### Scoreboarding and Dual Fetch

Lab 3 extends the core with `CoreScoreboard.v` and dual-fetch variants. This
lab focuses on tracking register dependencies and coordinating instruction
issue when multiple instructions may be considered in the same control window.

### Out-of-Order Execution

Lab 4 adds `riscvooo`, which includes:

- `riscvooo-CoreScoreboard.v`
- `riscvooo-CoreReorderBuffer.v`
- out-of-order control and datapath modules

The goal is to explore how a processor can allow independent operations to
progress while still committing architectural state in a controlled order.

### Cache Hierarchy

Lab 5 introduces cache configurations around the RISC-V core:

- `CacheNone`: no-cache configuration
- `CacheBypass`: bypass path
- `CacheIcache`: I-cache focused configuration
- `CacheDcache`: D-cache focused configuration
- `CacheAll`: combined I-cache and D-cache wrapper
- `CacheAlt`: more complete D-cache implementation
- `VictimCache`: victim-cache support

The included cache notes describe `CacheAlt` as a two-way set-associative
D-cache with victim-cache behavior and an FSM covering cache hits, misses,
writeback, refill, update, and victim-cache swap paths.

## Tests and Benchmarks

The repository includes two main validation surfaces:

- RISC-V assembly tests in `lab*/tests/riscv/`
- microbenchmarks in `lab*/ubmark/ubmark/`

The assembly tests cover common integer instructions, branches, jumps, loads,
stores, multiply/divide operations, and lab-specific cases such as dual-fetch
kill, out-of-order test programs, and victim-cache behavior.

The benchmark set includes:

- vector-vector add
- complex multiply
- masked filter
- binary search

## Build and Simulation

Each lab keeps generated files in a local `build/` directory. The generated
Makefiles expose the common targets:

```bash
cd lab3/build
make
make check
make clean
```

Several labs also define architecture-specific simulation targets. For example,
Lab 3 includes targets for `riscvlong`, `riscvdualfetch`, and `riscvssc`
simulation runs over the assembly tests and benchmarks.

The exact toolchain setup depends on the course environment used to generate
the build directories. At a high level, the flow expects:

- a Verilog simulator supported by the provided Makefiles
- a RISC-V cross-compilation flow for assembly tests and benchmarks
- standard Unix build tools such as `make`, shell scripts, and Perl/Ruby helper
  scripts used by the test summaries

## Generated Files Policy

The repository intentionally ignores generated files such as:

- `build/` directories
- waveform files such as `*.vcd`
- compiled objects and simulator binaries
- `*.out`, `*.dump`, `*.vmh`, and dependency files
- LaTeX auxiliary files
- local submission PDFs and archives

This keeps the GitHub repository focused on source code, diagrams, tests, and
documentation instead of simulator output.

## Notes

This repository is a learning-oriented architecture project. The lab sequence
is useful for studying how a processor grows from basic arithmetic units into a
more complete microarchitecture with pipeline control, dependency tracking,
out-of-order support, and cache behavior.
