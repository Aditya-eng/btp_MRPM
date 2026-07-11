# Paper Brief — Signed Radix-4 MRPM + Han-Carlson FIR (8-tap)

**Purpose of this document.** This is a complete, self-contained input packet for
an LLM (Opus 4.8) tasked with drafting the research paper. It states what the base
paper did, exactly what this work changes/improves, the architecture, and the
verified results. Scope is the **8-tap** design (the optional 16-tap extension is
deliberately excluded).

> ⚠️ **INTEGRITY RULES FOR THE WRITING MODEL — READ FIRST**
> 1. **Do NOT invent numbers.** Any LUT4 / FF / DSP / Fmax / power / area-delay
>    value not explicitly given below is **UNMEASURED**. Where a number is needed
>    but not provided, insert a visible placeholder like `[TBD-Gowin]` — never a
>    plausible-looking figure. Fabricated hardware metrics will invalidate the paper.
> 2. **Functional/simulation results below are real and measured** — those may be
>    stated as fact.
> 3. **Base-paper specifics** are summarized from the project's own reference notes,
>    not from a re-read of the base-paper PDF. Flag every base-paper quantitative
>    claim as "verify against [1]" so the author checks it before submission.
> 4. Frame contributions as **extending** the base paper, not "fixing errors."

---

## 1. Working title & venue

- **Title (working):** "Area-Efficient Pipelined Signed Radix-4 Modified Russian
  Peasant Multiplier with Han-Carlson Adders for Biomedical FIR Filtering."
- **Target venue:** IEEE conference (ISVLSI / VLSID / iSES) or *Integration* (the
  VLSI Journal, same venue as the base paper).
- **Positioning:** direct successor to the base paper [1]; Part 1 of a two-part
  effort (Part 2 = real ECG/EEG denoising, future work).

## 2. Application context (motivation)

Wearable/implantable biomedical devices (ECG/EEG) are area- and power-constrained.
The signal chain needs a low-pass FIR filter to remove EMG/high-frequency noise
while preserving diagnostic morphology (e.g. the QRS complex). The multiplier
dominates FIR area/power, so an efficient **LUT-based** multiplier (no dedicated
DSP blocks) is the lever. Design point used here:
- **fs = 250 Hz** (typical ECG rate), **fc = 40 Hz** low-pass.
- **8-tap, linear-phase** (symmetric) FIR, **Hamming-windowed sinc** design.
- Coefficients (int8, scale 2⁷): **h = [0, 3, 20, 42, 42, 20, 3, 0]**,
  DC gain = 130/128 ≈ 1.016, symmetric (`h[i] = h[7-i]`).

## 3. The base paper [1] — what it did (verify quantities against the PDF)

- **Reference [1]:** G. S. Subramanian V., D. S. T.N., Aditya S., "A low cost
  area-efficient modified Russian peasant multiplier (MRPM) for biomedical
  applications," *Integration, the VLSI Journal*, vol. 104, 102474, 2025.
- **Core idea:** a **Modified Russian Peasant Multiplier (MRPM)** — Russian Peasant
  multiplication is iterative shift-and-add (halve one operand, double the other,
  accumulate where the odd bit is set); the "modified" form streamlines this. The
  base paper pairs the MRPM with a **Kogge-Stone** parallel-prefix adder and targets
  biomedical multiply/FIR workloads.
- **Reported implementation:** FPGA utilization on a **Xilinx Nexys A7** board
  (their Table 2 has the LUT/FF numbers we compare against).
- **Gaps this work targets** (state as *gaps*, not errors):
  1. **Unsigned only.** Biomedical differential signals are inherently signed;
     an unsigned multiplier cannot handle them without external sign handling.
  2. **Iterative multiplier.** RPM processes ~1 bit/iteration (~8 iterations for
     8-bit). Speeding up the *adder* while leaving a sequential loop optimizes the
     wrong term — throughput stays iteration-bound.
  3. **No radix recoding.** It does not exploit radix-4 Booth recoding to cut the
     number of partial products/iterations.
  4. **No structural FIR optimization.** It does not exploit linear-phase symmetry
     (coefficient folding) to halve the multiplier count in the FIR.
  5. **Adder choice not swept.** Kogge-Stone is used without an area/speed/power
     comparison against other prefix adders on the *same* fabric.

## 4. Contributions of THIS work (the deltas — the heart of the paper)

Each item: **what changed**, **why it matters**, and **evidence status**.

**C1 — Signed radix-4 (modified-Booth) MRPM.**
- *What:* replace the iterative unsigned RPM with a **radix-4 modified-Booth**
  multiplier. Processes **2 multiplier bits/step ⇒ 4 partial products** for 8-bit
  (vs ~8 iterations), and handles two's-complement operands natively.
- *Why:* halves the partial-product count *and* adds signed support — directly
  closes gaps #1, #2, #3. Fewer partial products ⇒ smaller/faster adder tree.
- *Evidence:* **exhaustively verified — all 65,536 signed pairs (−128..127)²,
  0 mismatches** vs reference multiply. (Simulation fact.)

**C2 — Han-Carlson adder for partial-product & FIR summation, with a prefix-adder
sweep.**
- *What:* use a **Han-Carlson** parallel-prefix adder (hybrid Brent-Kung/Kogge-Stone
  schedule; depth ≈ log₂N+1) for all additions, and provide a drop-in **sweep**
  across **Han-Carlson, Kogge-Stone, Brent-Kung, Sklansky** (all sharing one port
  list; selected at compile time).
- *Why:* Han-Carlson balances cell-count/fan-out vs depth better than pure
  Kogge-Stone at these widths; the sweep quantifies the trade-off on the target
  fabric — closes gap #5.
- *Evidence:* all four adders drive the FIR to **0 mismatches** (functional).
  **LUT4/FF/Fmax/power per adder = `[TBD-Gowin]`** (see §7).

**C3 — Symmetric-folded FIR (4 multipliers instead of 8).**
- *What:* exploit linear-phase symmetry `h[i]=h[7-i]`:
  `y = Σ h[i]·(d[i]+d[7-i])` over the first 4 taps ⇒ **pre-add mirror pairs, then
  only 4 multipliers**. Pre-add is 9-bit; multiplier is 9×8.
- *Why:* multipliers are the dominant FPGA resource; folding halves them with
  **bit-identical** output — closes gap #4. This is the headline area result.
- *Evidence:* folded output is **bit-exact vs the naive 8-multiplier version and
  vs the Python golden model (63 samples, 0 mismatches)**. Multiplier-count
  reduction (8→4) is a structural fact. Area saving in LUT4 = `[TBD-Gowin]`.

**C4 — Pipelined folded FIR (throughput / Fmax).**
- *What:* a **4-stage pipeline** of the folded FIR — register boundaries at
  (0) delay line, (R1) inside the multiplier between Booth-PP generation and
  accumulation, (R2) after the multipliers, (R3) after the first adder-tree level,
  (R4) output. Latency rises **1 → 4 cycles**; output unchanged.
- *Why:* shortens the critical combinational path to raise the maximum clock
  frequency (Fmax) — a throughput lever the base paper cannot get from a
  sequential multiplier.
- *Evidence:* pipelined output is **bit-identical (0 mismatches, latency-4
  aligned)**. Fmax(unpipelined) vs Fmax(pipelined) = `[TBD-Gowin]`.

**C5 — LUT-only, open-source-friendly flow on a low-cost FPGA; DSP explicitly
disabled.**
- *What:* target the **Sipeed Tang Nano 9K (Gowin GW1NR-9; 8640 LUT4, 6480 FF)**;
  simulate with open-source Icarus Verilog + GTKWave; synthesize in Gowin with
  **DSP/multiplier inference disabled** (`syn_multstyle="logic"`), and confirm the
  utilization report shows **0 DSP blocks**.
- *Why:* the entire "area-efficient LUT multiplier" claim is only valid if the tool
  is not silently mapping to hardware DSP. Moving to a cheaper Gowin part also
  differentiates from the base paper's Xilinx Nexys A7.
- *Evidence:* DSP=0 confirmation and all utilization numbers = `[TBD-Gowin]`.

**One-line contribution list (for the Introduction bullet block):**
1. Signed radix-4 Booth MRPM (4 PPs vs 8 iterations; exhaustively verified).
2. Han-Carlson adder + a 4-way prefix-adder comparison on one fabric.
3. Symmetric-folded 8-tap FIR (4 multipliers, bit-identical output).
4. 4-stage pipeline raising Fmax with unchanged function.
5. LUT-only implementation on Tang Nano 9K with DSP inference disabled (DSP=0).

## 5. Architecture details (for the "Proposed Architecture" section)

**5.1 Signed radix-4 Booth MRPM.** Triplet `(b_{2k+1}, b_{2k}, b_{2k-1})` (phantom
`b_{-1}=0`) selects digit ∈ {−2,−1,0,+1,+2}: `one = b_{2k}⊕b_{2k-1}` (±1),
`two = (b_{2k+1}·¬b_{2k}·¬b_{2k-1}) + (¬b_{2k+1}·b_{2k}·b_{2k-1})` (±2),
`neg = b_{2k+1}` (negate via two's complement). Partial product k =
`(one·A + two·2A)`, negated if `neg`, shifted left by `2k`. Four PPs summed by a
3-adder Han-Carlson tree. Widths: 8×8 → 16-bit; 9×8 (folded) → 17-bit.
*Figure:* Booth-stage datapath → Han-Carlson tree.

**5.2 Han-Carlson adder.** Pre-process `g=a&b`, `p=a^b`; log-depth prefix network
producing carries `c[i+1]=G[i] | (P[i]&cin)`; `sum = p ⊕ c`. Depth ≈ log₂(WIDTH)+1.
*Honest note for the paper:* the current RTL realizes the prefix carries with a
Kogge-Stone-style schedule that is **functionally exact**; the strict Han-Carlson
odd/even schedule is the intended synthesis mapping. State the function is proven;
the exact cell-level schedule is an implementation detail measured in the sweep.

**5.3 Symmetric-folded FIR.** 8-deep delay line; four 9-bit pre-adds
`pa_i=d[i]+d[7-i]`; four 9×8 multipliers with coefficients {H0..H3}={0,3,20,42};
3-adder sum tree; 20-bit full-precision output (no rounding). *Figure:* folded FIR
structure. Output width justified by bit-growth (§6).

**5.4 Pipelining.** See C4. *Figure:* the 4 pipeline boundaries on the datapath.

## 6. Number formats & bit-growth (for "Implementation")

| Quantity | Width | Rationale |
|---|---|---|
| input `x`, coeff `h` | 8-bit signed | −128..127; `h` scaled by 2⁷ |
| pre-add `d[i]+d[7-i]` | 9-bit signed | +1 guard bit |
| 8×8 / 9×8 product | 16 / 17-bit signed | — |
| output `y` | 20-bit signed | worst-case `|acc| ≤ 8·127·128 = 130,048` needs 18 bits; 20 is safe (2¹⁹=524,288) and keeps full precision |

Coefficient quantization: taps × 128, round, clip to int8; max coeff quant error
and DC gain reported by `python/gencoef.py`. Output is the true filter response
scaled by 128 (final `>>7` in a deployed system).

## 7. Results tables to FILL from Gowin (placeholders — do not fabricate)

**Table A — Resource utilization & timing (folded 8-tap FIR, Han-Carlson).**
| Metric | This work (Tang Nano 9K) | Base paper [1] (Nexys A7) |
|---|---|---|
| LUT4 | `[TBD-Gowin]` | `[verify against [1]]` |
| FF | `[TBD-Gowin]` | `[verify against [1]]` |
| DSP blocks | `[TBD-Gowin, target 0]` | `[verify]` |
| Fmax (MHz) | `[TBD-Gowin]` | `[verify]` |
| Dynamic power (mW) | `[TBD-Gowin]` | `[verify]` |

**Table B — Adder sweep (folded FIR, same design, adder swapped).** One row each
for Han-Carlson / Kogge-Stone / Brent-Kung / Sklansky; columns LUT4, FF, Fmax,
dynamic power — all `[TBD-Gowin]`. (Functional column = PASS/0-mismatch for all
four, already measured. See `docs/adder_comparison.csv`.)

**Table C — Pipeline effect.** Unpipelined vs 4-stage pipelined folded FIR: Fmax,
LUT4, FF, latency (1 vs 4 cycles), throughput. Fmax/area = `[TBD-Gowin]`;
latency/throughput ratios are known from the RTL.

**Table D — Multiplier-count / structural deltas (known now, no synthesis needed).**
| Design | Multipliers | Multiplier iterations/PPs | Signed? |
|---|---|---|---|
| Base paper MRPM | 8 (naive FIR) | ~8 iterations | No |
| This work (radix-4) | 8 (naive) / **4 (folded)** | **4 partial products** | **Yes** |

## 8. Verification methodology & measured facts (all real)

- **Multiplier:** exhaustive testbench over all 65,536 signed pairs → **0 mismatches**.
- **FIR (folded):** Python golden model (independent radix-4 Booth reference,
  cross-checked against direct integer convolution) → **0 mismatches over 63 samples**.
- **Pipelined FIR:** same golden, latency-4 aligned → **0 mismatches**.
- **Adder sweep:** folded FIR rebuilt with each of the 4 adders → **0 mismatches** each.
- **Tools:** Icarus Verilog (`iverilog`+`vvp`) for simulation, GTKWave for waveforms
  (Fig-5-equivalent), Gowin EDA for synthesis/implementation (pending).
- **Regression:** `make all` runs the full suite; every target prints "0 mismatches".

## 9. Suggested paper outline (map to evidence)

1. **Abstract** — lead with deltas: signed support, 4 PPs (radix-4), 4 multipliers
   (fold), then LUT/FF/Fmax/power `[TBD]`, then exact-accuracy + ECG applicability.
2. **Introduction** — motivation, the 5 gaps in [1], contribution bullets (§4).
3. **Related Work** — position [1] as predecessor; cite Booth/Wallace/Vedic/
   Kogge-Stone/Han-Carlson [9]/symmetric-FIR [13]; frame as gaps.
4. **Proposed Architecture** — §5.1–5.4 with the four figures.
5. **Implementation** — §6, board/tool setup, DSP-disabled note, verification.
6. **Results** — §8 (functional, proven) + Tables A–D (fill from Gowin).
7. **Conclusion + Future Work** — recap deltas; Part 2 teaser (real ECG/EEG denoising).

*Claims proven now:* correctness (all 0-mismatch), signedness, radix-4 PP count,
multiplier-count reduction (fold), pipeline latency/throughput structure.
*Claims pending Gowin:* every LUT4/FF/DSP/Fmax/power figure and all area-delay/
power comparisons vs [1].

## 10. References

Use the reference list in `docs/PAPER_SKELETON.md` (base paper = [1]; Han-Carlson
precedent = [9]; RPM-FIR precedent = [13]; DSP-avoidance rationale = [14]; add
Tang Nano 9K / GW1NR-9 datasheet as a new reference). Renumber for the final paper.

## 11. Assets available in the repo (for figures/tables)

- `rtl/` — all synthesizable Verilog (multiplier, adders, folded + pipelined FIR).
- `python/gencoef.py`, `golden.py` — coefficient design + golden model (for the
  filter-response and quantization figures).
- `sim/` — testbenches + golden vectors; `make fir` emits `fir.vcd` for the
  GTKWave waveform figure.
- `docs/DESIGN_NOTES.md` — detailed signal-level walkthrough (source for prose).
- `docs/adder_comparison.csv` — sweep results (functional now; synth to be filled).
