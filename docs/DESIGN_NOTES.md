# Design Notes — MRPM FIR (BTP Part 1)

A file-by-file, signal-by-signal walkthrough of the whole project, written so
every design decision can be defended in a viva. Read alongside the RTL.

---

## 1. What the project builds, and why

An **8-tap linear-phase FIR low-pass filter** for ECG/EEG signals, built on a
custom **signed radix-4 modified-Booth multiplier (MRPM)** whose internal
additions use **parallel-prefix adders**. The thesis claim is *area-efficient
LUT-based arithmetic* on a small FPGA (Tang Nano 9K, Gowin GW1NR-9), i.e. good
filter throughput **without** using the FPGA's hardware DSP multipliers.

Signal-processing rationale (see `python/gencoef.py`):
- **fs = 250 Hz** — typical ECG sampling rate.
- **fc = 40 Hz** low-pass — the ECG diagnostic band is ~0.05–40 Hz; a 40 Hz LPF
  removes EMG / high-frequency noise while keeping QRS morphology.
- **Linear phase** (symmetric coefficients) — no phase distortion of the
  waveform, which matters clinically. Symmetry is also what enables the
  *fold* optimisation (Section 6).
- **Hamming-windowed sinc** — a smooth window to control passband ripple and
  stopband attenuation for a short (8-tap) filter.

---

## 2. Number formats and conventions

| Quantity | Width | Notes |
|---|---|---|
| Input sample `x` | 8-bit signed | −128…127 |
| Coefficient `h` | 8-bit signed | quantised at scale 2⁷ (Q-ish), see below |
| Pre-add `d[i]+d[N-1-i]` | 9-bit signed | sum of two 8-bit values needs 1 guard bit |
| 8×8 product | 16-bit signed | `mrpm_radix4` |
| 9×8 product | 17-bit signed | `mrpm_radix4_wide` |
| Filter output `y` | 20-bit signed | full precision, no rounding (Section 7) |

**Coefficient scaling:** floating taps are multiplied by `2⁷ = 128` and rounded
to int8. The output is therefore the *true* filter output scaled by 128; a real
system would shift right by 7 at the very end. We keep full precision so the
hardware is **bit-exact** against the integer golden model.

**All arithmetic is two's-complement.** "Bit-exact" throughout means the Verilog
output equals the Python golden output for *every* test vector, including any
overflow wrap (the golden model wraps identically, so equality still holds).

---

## 3. The adder: `rtl/han_carlson_adder.v`

The workhorse used everywhere additions happen.

**Interface:** `a, b` (WIDTH-bit) `+ cin → sum, cout`. Purely combinational.

**How a parallel-prefix adder works (the theory to state in viva):**
1. **Pre-process** — for each bit compute *generate* `g = a&b` (this bit forces a
   carry out) and *propagate* `p = a^b` (this bit passes an incoming carry).
2. **Prefix network** — combine (g,p) pairs in a tree so that after `log₂(WIDTH)`
   levels, `G[i]` = "is there a carry into position i+1 considering bits 0..i".
   The combine rule (a *black cell*) is:
   `G' = G_hi | (P_hi & G_lo)`, `P' = P_hi & P_lo`.
3. **Carries & sum** — `carry[i+1] = G[i] | (P[i] & cin)`, then `sum = p ⊕ carry`.

The depth is logarithmic in WIDTH, so it is much faster than a ripple adder
(linear depth) — this is the whole reason to use it in the multiplier and the
FIR adder tree.

> **Honest implementation note (say this if asked):** the generate loop in this
> file currently builds a **Kogge-Stone-style** prefix schedule (every bit
> combines with the bit `STRIDE` below it at each level). It computes the
> *correct* carries for any WIDTH and is functionally a valid parallel-prefix
> adder. The file's own comments flag that the strict Han–Carlson odd/even
> schedule (Brent-Kung outer stage + Kogge-Stone inner stages, which lowers cell
> count and fanout) is the intended mapping for the final synthesis. Functionally
> identical result; the difference is only in cell count / wiring, which is what
> the adder sweep (TASK 2) measures.

---

## 4. Adder variants: `rtl/adder_variants.v`

Three alternative adders sharing the **exact same port list** as
`han_carlson_adder`, so they drop in 1:1 for the comparison sweep:

- **`kogge_stone_adder`** — minimum logic depth, maximum number of prefix cells
  and wiring. Real parallel-prefix network.
- **`sklansky_adder`** — also minimum depth, but fewer cells at the cost of high
  fan-out at some nodes (the `SRC` index feeds many bits). Real prefix network.
- **`brent_kung_adder`** — minimum cells, higher depth. **Implementation note:**
  its body is written as a functionally-exact *ripple* carry reference (the
  comment says so); the intent is that the synthesiser infers the tree. If an
  examiner asks "is this really Brent-Kung?", the honest answer is: *the
  function is exact; the structural BK tree is left to synthesis / future work.*

The point of the sweep is to hold the filter fixed and swap only this adder, then
read LUT4 / FF / Fmax / power from Gowin for each — quantifying the classic
depth-vs-area-vs-fanout trade-off on real hardware.

---

## 5. The multiplier: radix-4 modified Booth (MRPM)

### 5.1 `rtl/mrpm_radix4.v` — 8×8 signed, combinational

Radix-4 Booth processes **2 multiplier bits per step**, so an 8-bit multiplier
needs only **4 partial products** instead of 8. For *signed* operands this
recoding handles the sign natively (no unsigned correction needed) — that is why
it is the right choice here.

**Booth recoding (the core table to memorise):** examine the triplet
`(b_{2k+1}, b_{2k}, b_{2k-1})` with a phantom `b_{-1}=0` (that is `bm = {b,1'b0}`):

| triplet | digit | meaning |
|---|---|---|
| 000 | 0 | `one=0, two=0` |
| 001 | +1 | `one=1` |
| 010 | +1 | `one=1` |
| 011 | +2 | `two=1` |
| 100 | −2 | `neg=1, two=1` |
| 101 | −1 | `neg=1, one=1` |
| 110 | −1 | `neg=1, one=1` |
| 111 | 0 | `neg=1` but `one=two=0` |

The three control signals in the code implement exactly this:
- `one = b_2k ^ b_2km1` → magnitude-1 cases,
- `two = (b_2kp1 & ~b_2k & ~b_2km1) | (~b_2kp1 & b_2k & b_2km1)` → magnitude-2,
- `neg = b_2kp1` → negate (subtract) when the triplet's MSB is set.

Then per stage k: `mag = one·A + two·(2A)` (A = sign-extended multiplicand),
negate via two's complement (`~mag + 1`) if `neg`, and left-shift by `2k` to put
the partial product at its correct weight. The four partial products are summed
by a small **Han-Carlson adder tree** (A0,A1 in parallel, A2 combines).

**Verification:** `sim/tb_mrpm.v` checks all **65 536** input pairs
(−128…127 × −128…127) against Verilog's `*`. Result: 0 mismatches → the
multiplier is provably bit-exact.

### 5.2 `rtl/mrpm_radix4_wide.v` — parameterized AW×BW

Same algorithm, but with parameters `AW` (multiplicand width) and `BW`
(multiplier width). Used by the folded FIR as **9×8** (9-bit pre-added sample ×
8-bit coefficient → 17-bit product). Odd `BW` is padded to even (`BWE`) so Booth
always has an even number of multiplier bits. Accumulator still hardcodes 4
partial products (valid for BW=8).

### 5.3 `rtl/mrpm_radix4_wide_pipe.v` — pipelined multiplier (TASK 1)

Identical function to 5.2, with **one pipeline register** inserted **between
partial-product generation and the accumulation tree** (`pp_r`). This splits the
multiplier's combinational path in half, shortening the critical path so the
clock can run faster. Latency: 1 cycle. The product `p` is combinational from the
*registered* partial products, so the next module can register it again ("after
multipliers" boundary).

---

## 6. The FIR filters

### 6.1 Symmetry and folding (the headline area result)

For a symmetric filter `h[i] = h[N-1-i]`:
```
y = Σ h[i]·d[i]  =  Σ_{i<N/2} h[i]·( d[i] + d[N-1-i] )
```
So instead of N multipliers you **pre-add the mirror-image sample pairs first**
and use only **N/2 multipliers**. Same output, half the multipliers — the
expensive resource on a LUT-based FPGA. The pre-add sum needs 1 extra bit
(9-bit), which is why the folded design uses the *wide* 9×8 multiplier.

### 6.2 `rtl/fir8_symmetric.v` — 8-tap, naive 8-multiplier reference

The straightforward version: an 8-deep delay line `d[0..7]`, **8** `mrpm_radix4`
8×8 multipliers (one per tap), and a 7-adder Han-Carlson sum tree. It keeps the
plain 8×8 multiplier interface (no pre-add), so it uses the full 8 multipliers.
This is the **baseline** the fold is compared against.
Latency: 1 cycle (`y_out` register). Output 20-bit.

### 6.3 `rtl/fir8_fold.v` — 8-tap, symmetric-folded (4 multipliers)

The headline design. Delay line `d[0..7]`; four 9-bit pre-adds
`pa0..pa3 = d[i]+d[7-i]`; **4** `mrpm_radix4_wide` 9×8 multipliers; a 3-adder tree
(`T0,T1` in parallel, `T2` combines). Same 20-bit output as `fir8_symmetric`,
**bit-identical**, but half the multipliers.

**Swappable adder (TASK 2):** the tree adders are instantiated through a macro:
```verilog
`ifndef FIR_ADDER
`define FIR_ADDER han_carlson_adder   // default → existing builds unchanged
`endif
`FIR_ADDER #(.WIDTH(OW)) T0(...);
```
Compile with `-D FIR_ADDER=kogge_stone_adder` (etc.) to build each sweep variant
without touching the source. All four adders share the port list, so it is a
one-symbol swap.

**Latency = 1 cycle.** The delay line loads sample `x` at clock edge *t*; the
combinational path (pre-add → multiply → adder tree) produces `t2`; the single
output register `y_out` publishes it at edge *t+1*. The testbench therefore
compares `yq[i+1]` against golden `ya[i]`.

### 6.4 `rtl/fir8_fold_pipelined.v` — pipelined fold (TASK 1)

Same math as 6.3, but pipelined to raise Fmax. **Four register stages** on the
`d → y_out` path (three new, plus the existing output register):

| Stage | Register | Purpose |
|---|---|---|
| 0 | delay line `d[]` (exists) | hold samples |
| R1 | inside multiplier (`pp_r`) | split Booth-gen from accumulate |
| R2 | products `p*_r` (new) | "after multipliers" |
| R3 | first adder level `t0_r,t1_r` (new) | "after first adder-tree level" |
| R4 | output `y_out` (exists) | publish result |

Each register shortens the longest combinational path, allowing a higher clock.
Because there are now 4 registers between `d` and `y_out` (vs 1), the **latency
is 4 cycles**. `out_valid` is produced by delaying `in_valid` through a matching
shift register (`vpipe`) so a downstream block knows when `y_out` is valid.
The pipelined testbench compares `yq[i+4]` against golden `ya[i]`. Output is
**bit-identical** to the unpipelined filter — pipelining changes *timing*, not
*function*.

### 6.5 `rtl/fir16_fold.v` — 16-tap folded (TASK 4, only in the full repo)

Same fold pattern scaled to 16 taps: delay line `d[0..15]`, eight 9-bit
pre-adds, **8** 9×8 multipliers, and a **3-level** balanced adder tree
(8→4→2→1). Coefficients `[0,0,-1,-4,-3,7,25,39,…]` — note these include
**negative** taps, which exercise the signed multiplier path more thoroughly
than the all-positive 8-tap set. Latency = 1 cycle (mirrors `fir8_fold`). The
sharper 16-tap response is a stronger filter for the paper; it is kept optional
because it adds length without changing the core contribution.

---

## 7. Bit-growth / output width (why 20 bits)

Worst-case accumulator magnitude bounds the output width:
- 8-tap: `|acc| ≤ 8 · 127 · 128 = 130 048` → needs 18 bits signed.
- 16-tap: `|acc| ≤ 16 · 127 · 128 = 260 096` → needs 19 bits signed.

We choose **20-bit** output for both — comfortably safe (2¹⁹ = 524 288 > both
bounds) with headroom, and no rounding so the result stays full-precision and
bit-exact. `gencoef*.py` prints this analysis; `golden16.py` asserts the 20-bit
bound actually holds for its vectors.

---

## 8. The golden model and coefficient generation (Python)

- **`python/gencoef.py`** — designs the 8-tap filter (windowed-sinc + Hamming),
  quantises to int8 at scale 2⁷, prints symmetry / DC-gain / quantisation-error
  checks, and saves `taps_q.npy`.
- **`python/golden.py`** — contains a *reference* radix-4 Booth multiply
  (`rpm_radix4_signed`) verified exhaustively against Python `*`, an integer FIR
  (`fir_fixed`) cross-checked against direct convolution, and writes the test
  vectors `mult_vectors.txt` and `fir_vectors.txt` the Verilog testbenches read.
- **`python/gencoef16.py` / `golden16.py`** — the 16-tap counterparts. They write
  **separate** artifacts (`taps16_q.npy`, `sim/fir16_vectors.txt`) so the verified
  8-tap flow is never disturbed. *(Full repo only.)*

The golden model is the *specification*: the RTL is correct **iff** it matches
these vectors exactly.

---

## 9. Testbenches and the Makefile

Each testbench streams the input vectors, captures the DUT output with the right
latency offset, and prints `N mismatches` (0 = pass):

| Testbench | DUT | Latency offset | Vectors |
|---|---|---|---|
| `tb_mrpm.v` | `mrpm_radix4` | combinational | exhaustive 65 536 pairs |
| `tb_fold.v` | `fir8_fold` | `yq[i+1]` | `fir_vectors.txt` |
| `tb_fir_selfcheck.v` | `fir8_fold` (+VCD dump) | `yq[i+1]` | `fir_vectors.txt` |
| `tb_fold_pipelined.v` | `fir8_fold_pipelined` | `yq[i+4]` | `fir_vectors.txt` |
| `tb_fir16_fold.v` | `fir16_fold` | `yq[i+1]` | `fir16_vectors.txt` *(full repo)* |

**Makefile targets:** `mult`, `fold`, `fir`, `pipe`, `fir16` (full repo only),
and `sweep` (builds the folded FIR four times, once per adder). `make all` runs
the full regression; **every target must print 0 mismatches**. Tooling:
Icarus Verilog (`iverilog` + `vvp`).

---

## 10. What is *not* in the RTL (measured in Gowin, not simulation)

Per the project rule "never claim a result you didn't measure", the following
come only from Gowin synthesis/implementation reports and are intentionally left
`PENDING` in `docs/adder_comparison.csv`:
- **LUT4 / FF / Fmax / dynamic power** for each adder variant (TASK 2).
- **DSP-disabled synthesis** (TASK 3): the GW1NR-9 has hardware DSP multipliers;
  the whole "LUT-efficient" claim requires forcing multiplier logic into LUTs
  (`syn_multstyle="logic"` or the synthesis DSP-inference option) and confirming
  the utilisation report shows **0 DSP blocks**.

Simulation proves **functional correctness**; Gowin provides the **area/speed/
power numbers**. Both are needed for the paper.

---

## 11. Fast viva Q&A

- **Why radix-4 Booth?** Halves the partial products (4 instead of 8 for 8-bit)
  and handles signed operands natively — fewer adds, less area.
- **Why parallel-prefix adders?** Logarithmic carry depth → higher Fmax than
  ripple, which matters because additions dominate both the multiplier and the
  FIR tree.
- **Why does folding save area?** Linear-phase symmetry lets one multiplier serve
  a mirror-image tap pair after a cheap pre-add → N/2 multipliers.
- **Does pipelining change the output?** No — bit-identical; it only adds latency
  (1→4 cycles) to shorten the critical path and raise Fmax.
- **How do you know the multiplier is correct?** Exhaustive 65 536-pair test,
  0 mismatches, plus an independent Python Booth reference.
- **Why 20-bit output?** Worst-case accumulator needs 18 (8-tap) / 19 (16-tap)
  bits; 20 is safe with headroom and keeps the result full-precision.
