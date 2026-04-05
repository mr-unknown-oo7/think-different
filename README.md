# INT8 convolution engine for deep learnign acceleration
# Row-Stationary Convolution Accelerator

A hardware accelerator designed in Verilog for 2D convolution using a **3×3 kernel** on an input feature map of up to **5 rows × 16 columns**. The design uses a **row-stationary dataflow** where weights are held stationary inside each PE row while input activations shift through horizontally.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Module Descriptions](#module-descriptions)
- [Dataflow & Execution Model](#dataflow--execution-model)
- [Opcode / Control Interface](#opcode--control-interface)
- [File Structure](#file-structure)
- [Testbench Summary](#testbench-summary)
- [Known Issues & Notes](#known-issues--notes)
- [Simulation Instructions](#simulation-instructions)

---

## Architecture Overview

```
                      ┌───────────────────────────────────────────────┐
  in_int8_bus ──────► │            top_mod                            │
  ctrl[3:0]  ──────►  │                                               │
  y_dim_ip   ──────►  │  IN_FIFO (async) ──► comp_core_v1_3x3         │
  mem_clk    ──────►  │                            │                  │
  compute_clk──────►  │                        ┌───┴───────────┐      │
                      │                        │  w_mem_3x3    │      │
                      │                        │  d_mem_3x3    │      │
                      │                        │  pe_array     │      │
                      │                        │  master_fsm   │      │
                      │                        │  pe_array_fsm │      │
                      │                        │  psum_trans   │      │
                      │                        └───────────────┘      │
  out_int32_data◄───  │                              │                │
  out_addr    ◄─────  │     OUT_FIFO (async) ◄───────│                │
                      └───────────────────────────────────────────────┘
```

The core is clocked independently from the memory interface via a dual-clock async FIFO boundary in `top_mod`.

---

## Module Descriptions

### `top_mod`
Top-level wrapper. Bridges two clock domains:
- **Memory side** (`mem_clk`): receives 8-bit data from main memory and control opcodes.
- **Compute side** (`compute_clk`): drives the compute core.
- Two `async_fifo` instances decouple the domains:
  - `IN_FIFO` (8-bit, 1 MB): buffers incoming weight/activation bytes.
  - `OUT_FIFO` (16-bit, 16 entries): buffers partial-sum output results.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `y_dim_ip` | in | 4 | Number of columns in the input feature map |
| `in_int8_bus` | in | 8 | Incoming data (weights or activations) |
| `ins_valid` | in | 1 | Latch ctrl and y_dim on this pulse |
| `ctrl` | in | 4 | Operation opcode (see table below) |
| `rst_n` | in | 1 | Active-low global reset |
| `mem_clk` | in | 1 | Memory-side clock |
| `compute_clk` | in | 1 | Compute-side clock |
| `out_int32_data` | out | 16 | Convolution output value |
| `exe_done` | out | 1 | High when current execution completes |

---

### `comp_core_v1_3x3`
Compute core. Instantiates and connects all sub-modules. Acts as the datapath integrator.

Responsibilities:
- Muxes incoming FIFO data between `w_mem_3x3` (weights) and `d_mem_3x3` (activations) based on `mux_ctrl` from the master FSM.
- Passes weight and activation channels to the PE array.
- Collects PE partial sums and forwards them to the psum transmitter.

---

### `master_fsm`
Top-level sequencer for the compute core. Implements an 9-state Moore FSM.

| State | Description |
|-------|-------------|
| `IDLE` | Powered-down state |
| `RETRIEVE` | Latches the current opcode; asserts `next` |
| `RESET_X` | Issues reset to data memory (`d_mem`) |
| `RESET_Y` | Issues reset to weight memory (`w_mem`) |
| `PRE_UPDT_X` | One-cycle pulse to assert `updt_x` before load |
| `UPDT_X` | Drives `updt_x_fsm` to stream activations into `d_mem` |
| `PRE_UPDT_Y` | One-cycle pulse to assert `updt_y` before load |
| `UPDT_Y` | Drives `updt_y_fsm` to stream weights into `w_mem` |
| `EXE` | Raises `exe_ready`; waits for `exe_done` from psum transmitter |

Instantiates four sub-FSMs: `reset_x_fsm`, `reset_y_fsm`, `updt_x_fsm`, `updt_y_fsm`.

---

### `pe_array_fsm`
Controls the timing of the PE array operations.

| State | Outputs |
|-------|---------|
| `IDLE` | shift_x=1, exe=0 |
| `LOAD_X` | shift_x=1; counts 3 cycles; fires done_load_x |
| `LOAD_W` | shift_x=1; counts 3 cycles; fires done_load_w |
| `SHIFT_X` | shift_x=1 for one cycle (slide input window) |
| `EXE_P_ARRAY` | exe_p_array=1 (trigger MAC) |
| `EXE_PSUM_TRANS` | exe_psum_trans=1; loops back to SHIFT_X until p_sum_trans_done |

---

### `pe_array`
3×3 systolic array of processing elements (9 PEs total), organised as 3 rows × 3 columns.

- Each **row** shares one weight bus (`w_bus_1/2/3`).
- Each **PE(i,j)** receives input `x_bus[i+j]`, implementing a sliding 1D convolution window.
- After `exe`, each PE produces `result = A[0]*B[0] + A[1]*B[1] + A[2]*B[2]`.
- Row sums are accumulated in a registered adder tree: `sum[k] = result[3k] + result[3k+1] + result[3k+2]`.

> **Note:** `x_bus[3]` is wired to `x_bus_3` (same as index 2) instead of `x_bus_4`. This appears to be a wiring oversight in `pe_array.v`.

---

### `pe`
Single processing element. Holds three 8-bit weight registers (`A[0..2]`) and three 8-bit activation registers (`B[0..2]`).

- On `shift_val_x=1`: shifts `B` left by one position (`B[2]<=B[1]<=B[0]<=b_ip`).
- On `exe=1`: computes `result = A[0]*B[0] + A[1]*B[1] + A[2]*B[2]` (16-bit output).
- `A` registers are never loaded via the `a_ip` port (the port is declared but the internal write logic is missing — requires fix).

---

### `w_mem_3x3`
Weight memory. Holds a 3×3 = 9-entry buffer.

- Writes serially via `valid`/`data` starting from `mem_cntr=0` after `updt`.
- Outputs three simultaneous weight values for one kernel column: `output_data_ch_1/2/3`.
- Output pointers start at `{0, 3, 6}` (SKIP_VAL=3) and advance via `ptr_incr`.

---

### `d_mem_3x3`
Data/activation memory. Holds up to 5×16 = 80 entries.

- Writes serially via `valid`/`data`.
- Outputs five simultaneous row values: `output_data_ch_1..5`.
- Output pointers start at `{0, y_dim, 2*y_dim, 3*y_dim, 4*y_dim}` and advance via `ptr_incr`.
- `y_dim` is captured from `y_dim_ip` on the `updt` pulse.

---

### `psum_trasnmitter`
Serialises the three partial-sum outputs from the PE array into the output FIFO.

| State | Action |
|-------|--------|
| `IDLE` | Waits for `exe` |
| `TRANS_1` | Drives `op_val_1` onto bus; stalls if `full` |
| `TRANS_2` | Drives `op_val_2`; stalls if `full` |
| `TRANS_3` | Drives `op_val_3`; asserts `done`; stalls if `full` |

---

### Sub-FSMs: `reset_x_fsm`, `reset_y_fsm`
Minimal two-state FSMs (IDLE/EXE). On `exe`, immediately assert `reset=1` and `done=1` for one clock cycle, then return to IDLE.

---

### Sub-FSMs: `updt_x_fsm`, `updt_y_fsm`
Five-state FSMs managing memory load handshake.

- `updt_x_fsm`: counts 8 pointer increments (fixed, for 9-weight rows) then asserts `load_x`.
- `updt_y_fsm`: counts `y_dim_ip` pointer increments (configurable) then asserts `load_y`.

Both use a `BUFF` state to hold `load_*` high until the PE array FSM acknowledges via `done_load_*`.

---

## Dataflow & Execution Model

### Row-Stationary Dataflow
Weights for one kernel row are loaded into the A-registers of the corresponding PE row and held stationary for the entire computation of one output row. Input activations are shifted horizontally through the B-registers of every PE.

### Convolution Execution Sequence

```
1. RESET_X  (ctrl=0x1)  – reset data memory pointers
2. RESET_Y  (ctrl=0x2)  – reset weight memory pointers
3. UPDT_Y   (ctrl=0x4)  – stream 9 weight bytes into w_mem
4. UPDT_X   (ctrl=0x3)  – stream (5 × y_dim) activation bytes into d_mem
5. EXE      (ctrl=0x5)  – run MAC + transmit partial sums
   └─ pe_array_fsm loops:  SHIFT_X → EXE_P_ARRAY → EXE_PSUM_TRANS
      until p_sum_trans_done for all output columns
```

### Output Layout
For a 5-row input and 3×3 kernel, each EXE produces **3 partial sums** (one per output row), transmitted sequentially through `psum_trasnmitter`.

---

## Opcode / Control Interface

| `ctrl[3:0]` | Operation | Action |
|-------------|-----------|--------|
| `0000` | IDLE | No operation |
| `0001` | RESET_X | Reset data memory pointers |
| `0010` | RESET_Y | Reset weight memory pointers |
| `0011` | UPDT_X | Load activation data into d_mem |
| `0100` | UPDT_Y | Load weights into w_mem |
| `0101` | EXE | Execute convolution |

---

## File Structure

```
project_root/
├── rtl/
│   ├── top_mod.v              # Top-level with async FIFOs
│   ├── comp_core_v1_3x3.v    # Compute core integrator
│   ├── master_fsm.v           # Main sequencer FSM
│   ├── pe_array_fsm.v         # PE array timing controller
│   ├── pe_array.v             # 3×3 systolic PE array
│   ├── pe.v                   # Single processing element
│   ├── w_mem_3x3.v            # Weight memory (3×3)
│   ├── d_mem_3x3.v            # Data memory (5×16)
│   ├── psum_trasnmitter.v     # Partial-sum output serialiser
│   ├── reset_x_fsm.v          # d_mem reset FSM
│   ├── reset_y_fsm.v          # w_mem reset FSM
│   ├── updt_x_fsm.v           # Activation load FSM
│   └── updt_y_fsm.v           # Weight load FSM
└── tb/
    ├── pe_tb.v
    ├── pe_array_tb.v
    ├── w_mem_3x3_tb.v
    ├── d_mem_3x3_tb.v
    ├── psum_trasnmitter_tb.v
    ├── reset_x_fsm_tb.v
    ├── reset_y_fsm_tb.v
    ├── updt_x_fsm_tb.v
    ├── updt_y_fsm_tb.v
    ├── pe_array_fsm_tb.v
    ├── master_fsm_tb.v
    └── comp_core_v1_3x3_tb.v
```

---

## Testbench Summary

| Testbench | DUT | Key Tests |
|-----------|-----|-----------|
| `pe_tb` | `pe` | Reset, B-shift pipeline, MAC, exe=0 hold, 16-bit overflow |
| `pe_array_tb` | `pe_array` | Reset, weight/activation loading, sum accumulation, zero weights |
| `w_mem_3x3_tb` | `w_mem_3x3` | Reset, serial write, ptr output, ptr_incr, updt re-arm |
| `d_mem_3x3_tb` | `d_mem_3x3` | Reset, y_dim stride, serial write, ptr_incr, y_dim=8 |
| `psum_trasnmitter_tb` | `psum_trasnmitter` | IDLE, 3-phase transmit, FIFO back-pressure, reset mid-tx |
| `reset_x_fsm_tb` | `reset_x_fsm` | IDLE, exe trigger, single-cycle reset pulse, re-trigger, rst_n |
| `reset_y_fsm_tb` | `reset_y_fsm` | Same as reset_x_fsm (structural twin) |
| `updt_x_fsm_tb` | `updt_x_fsm` | IDLE, empty stall, 8-cycle count, BUFF/load handshake, rst_n |
| `updt_y_fsm_tb` | `updt_y_fsm` | y_dim=4 and y_dim=8 load counts, BUFF handshake, rst_n |
| `pe_array_fsm_tb` | `pe_array_fsm` | LOAD_X/W, SHIFT_X loop, EXE_P_ARRAY, EXE_PSUM_TRANS, p_sum_trans_done |
| `master_fsm_tb` | `master_fsm` | All opcodes, RETRIEVE dispatch, sub-FSM completion, rst_n |
| `comp_core_v1_3x3_tb` | `comp_core_v1_3x3` | Full opcode sequence: RESET→UPDT→EXE, output monitoring |

---

## Known Issues & Notes

1. **`pe.a_ip` port is unconnected internally.** The `A[]` weight registers inside each PE are never written through the `a_ip` input — the write logic is missing. Testbenches use `force`/`release` to work around this. The `a_ip` port should be connected to an internal write path triggered by a dedicated load signal.

2. **`pe_array` x_bus wiring bug.** `x_bus[3]` is assigned `x_bus_3` (same signal as index 2) rather than `x_bus_4`. This means PE(2,1) and PE(2,0) see the same input, producing incorrect convolution results for the third output row.

3. **`psum_trasnmitter` next-state bug.** The next-state logic uses `next_state` instead of `state_reg` in the case statement — effectively making it combinational self-assignment. The correct pattern is `case(state_reg)` for the present state.

4. **`comp_core_v1_3x3` signal mismatches.** Several internal signals (`valid_from_fifo_y`, `done_load_w` in the pe_array_fsm instance) reference undeclared or inconsistently named wires. These will cause compile errors and need reconciliation.

5. **`updt_y_fsm` undeclared wire.** `done_temp_2` is assigned but never declared — add `wire done_temp_2;`.

6. **`top_mod` incomplete.** References `async_fifo`, `valid` (undeclared), `int8_rd_data` (undeclared), `wr_data` (undeclared), and `rd_data` (undeclared). The module is a structural skeleton requiring these to be fully wired.

---



