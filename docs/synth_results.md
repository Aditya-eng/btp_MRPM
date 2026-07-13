# Synthesis Results — Tang Nano 9K (GW1NR-9C)

Device budget: **8640 LUT4, 6480 FF**. Tool: Gowin EDA. DSP inference disabled;
**DSP = 0 confirmed for all six runs** (see `docs/GOWIN_SYNTHESIS_STEPS.md`).

Numbers below are read from the Gowin Place-and-Route resource report, Timing
Analyzer, and Power Analyzer. Percentages are computed from the measured LUT4/FF
counts against the device budget.

Power toggle-rate assumption: not separately recorded — values are the Gowin Power
Analyzer output for each run under the same tool default (kept identical across
runs, so cross-config comparison is valid; state the exact default in the paper
after re-checking the Power Analyzer setting).

---

## Table 1 — All configurations

| Config | Top module | LUT4 | LUT4 % | FF | FF % | DSP | Fmax (MHz) | Dyn power (mW) |
|---|---|---|---|---|---|---|---|---|
| A — Direct FIR | `fir8_symmetric` | 345 | 4.0% | 44 | <1% | 0 | 42.858 | 2.582 |
| B — Folded (Han-Carlson) | `fir8_fold` | 222 | 2.6% | 44 | <1% | 0 | 42.956 | 2.595 |
| C — Folded + pipelined | `fir8_fold_pipelined` | 324 | 3.8% | 159 | 2.5% | 0 | 66.471 | 2.639 |
| D — Folded, Kogge-Stone | `fir8_fold` | 222 | 2.6% | 44 | <1% | 0 | 42.956 | 2.595 |
| D — Folded, Brent-Kung | `fir8_fold` | 223 | 2.6% | 44 | <1% | 0 | 41.762 | 2.595 |
| D — Folded, Sklansky | `fir8_fold` | 238 | 2.8% | 44 | <1% | 0 | 44.955 | 2.599 |

Source: Gowin PnR resource report (LUT4/FF/DSP), Timing Analyzer (Fmax), Power
Analyzer (dynamic power). DSP=0 verified in every PnR report.

**Note on FF count (44).** An 8-deep × 8-bit delay line is 64 flip-flops on its own,
yet A/B report 44 FF. This indicates Gowin maps the sample delay line to **LUT-based
shift registers** rather than dedicated FFs (the FFs counted are the output/pipeline
registers). Confirm in the report and state it in the paper — it is part of why the
LUT counts are what they are.

**Note on Han-Carlson ≡ Kogge-Stone (rows B and D-KS identical).** In the current RTL
`han_carlson_adder.v` implements a Kogge-Stone-style prefix network (its prefix
loop is structurally identical to `kogge_stone_adder.v`), so the two synthesize to
the *same* netlist — hence identical LUT4/FF/Fmax/power. This is expected, not a
measurement error. A genuine Han-Carlson-vs-Kogge-Stone comparison would require
implementing the true Han-Carlson odd/even schedule; as-is, treat HC and KS as one
data point.

---

## Analysis 1 — Direct (A) vs Folded (B): the real fold saving

- LUT4 saving = (345 − 222) / 345 = **35.7 %**.
- As predicted, this is **well below the naive 50 %**. Folding replaces 8 × (8×8)
  multipliers with 4 × (9×8) multipliers — individually wider/costlier — and adds
  4 nine-bit pre-adders, which claw back part of the multiplier saving.
- FF change A→B: 44 → 44 (**Δ = 0**) — both are latency-1; the delay line dominates
  and is identical, so FF count is unchanged. ✓
- Power A→B: 2.582 → 2.595 mW (essentially flat; the fold trades multiplier count
  for multiplier width + pre-adders at similar switching).
- **Attribution caveat:** splitting the 35.7 % precisely into "wider-multiplier cost"
  vs "pre-adder cost" requires the **per-module hierarchical utilization** from Gowin
  (LUT4 per `mrpm_radix4` vs per `mrpm_radix4_wide`, and per 9-bit pre-adder). That
  breakdown was not captured in this pass — re-run with the hierarchical resource
  report if the paper needs the split. Do **not** estimate it from the totals.

## Analysis 2 — Folded (B) vs Pipelined (C): Fmax vs cost

- Fmax gain = 66.471 / 42.956 = **1.55×** (42.956 → 66.471 MHz).
- FF cost = 159 − 44 = **+115 FF** (the pipeline registers R1–R3).
- LUT4 cost = 324 − 222 = **+102 LUT4**.
- Latency = 1 → 4 cycles. Throughput at Fmax (1 sample/cycle) = 42.96 → 66.47
  Msample/s (= the same 1.55×).
- Power B→C: 2.595 → 2.639 mW (+1.7 %).
- **Verdict:** pipelining buys 1.55× throughput/Fmax for +115 FF, +102 LUT4, and
  +3 cycles latency. For the ECG application (fs = 250 Hz) both are enormously
  over-provisioned, so pipelining matters for the **VLSI/Fmax contribution**, not
  the application throughput.

## Analysis 3 — Adder ranking (D)

Scope: only the 3 FIR-tree adders differ; the 12 adders inside the multipliers stay
Han-Carlson — hence small deltas. (HC ≡ KS in this RTL, see note above.)

| Adder | LUT4 | Fmax (MHz) | Dyn power (mW) |
|---|---|---|---|
| Han-Carlson | 222 | 42.956 | 2.595 |
| Kogge-Stone | 222 | 42.956 | 2.595 |
| Brent-Kung | 223 | 41.762 | 2.595 |
| Sklansky | 238 | 44.955 | 2.599 |

- **Smallest area:** Han-Carlson / Kogge-Stone (222 LUT4); Brent-Kung essentially
  tied (223).
- **Highest Fmax:** **Sklansky** (44.955 MHz, +4.7 % over HC) — at a +16 LUT4 (+7 %)
  area cost.
- **Lowest power:** HC / KS / BK tie at 2.595 mW; the spread across all four is
  0.15 % — negligible, as expected when only 3 of ~15 adders change.
- **Does Han-Carlson win here?** At 20-bit width, HC (= KS) gives the best
  area **and** beats Brent-Kung on both area (222 vs 223) and speed (42.96 vs 41.76).
  Sklansky is the only way to go faster, trading area for +2.0 MHz. Brent-Kung offers
  no advantage at this width. **Recommendation for the design: Han-Carlson/Kogge-Stone
  for area-optimal, Sklansky if Fmax-bound.**

---

## Comparison vs base paper [1] (from its Table 1 & Table 2)

Base paper measures a **standalone 8-bit *unsigned* multiplier** on a **Nexys A7
(XC7A100T)**; this work measures a full **8-tap signed FIR** on Tang Nano 9K. So the
rows are NOT apples-to-apples — read with the caveats below.

| Metric | This work (Tang Nano 9K, GW1NR-9C) | Base paper [1] (Nexys A7, XC7A100T) |
|---|---|---|
| Unit measured | full 8-tap FIR (folded, 4 mults) | one 8-bit multiplier |
| Signed | **Yes** | No (unsigned) |
| LUT | 222 LUT4 (folded) / 345 (direct) | 68 LUTs (Table 1/2) |
| FF (registers) | 44 | 58 |
| DSP | **0** (confirmed) | not reported (LUT-based) |
| Fmax | 42.96 (folded) / 66.47 (pipelined) MHz | 0.714 MHz |
| Critical-path delay | — (not captured) | 17.217 ns |
| Dynamic power | 2.595 mW | 1.136 W (see note) |

Base paper Table 2 (8-bit multiplier LUT comparison, for context): Proposed MRPM **68**,
Vedic [4] 114, Array [4] 116, Booth [4] 118, Vedic+Kogge-Stone [17] 309, Reduced-complexity
Wallace [6] 224 LUTs.

**Caveats — state these; do not overclaim:**
1. **Multiplier vs FIR.** Their 68 LUT / 0.714 MHz / 1.136 W is one multiplier; our 222 LUT
   is a whole FIR (4 multipliers + adder tree + delay line). For a true like-for-like, also
   synthesize our standalone `mrpm_radix4` (8×8) on this flow — recommended extra run.
2. **Fmax gap (0.714 → 42.96/66.47 MHz).** Their multiplier is *iterative* (~8 cycles);
   ours uses a *combinational* radix-4 multiplier. The >60× gap reflects iterative-vs-parallel
   architecture, not tuning alone — a strong qualitative point, not a clean 1:1 speedup.
3. **Power W vs mW.** They report 1.136 W, we report 2.595 mW (~440×). Almost certainly
   different tools/toggle-rate methodology (1.1 W for a 68-LUT design is implausible). Do NOT
   claim a power win; flag the methodology difference.
4. **Fabric.** Gowin GW1NR-9 LUT4 vs Xilinx 6-input LUT — counts not 1:1. Lead with the
   *architectural* deltas (signed, radix-4, fold, pipeline, DSP=0).

---

## Open items before submission

1. Fill the base-paper column from [1] (Table 2) — currently `[verify]`.
2. (Optional) capture per-module hierarchical LUT4 for the Analysis-1 attribution split.
3. (Optional) record the exact Power Analyzer toggle-rate setting used.
4. (Optional) implement the true Han-Carlson schedule if a distinct HC-vs-KS row is
   wanted; otherwise present HC and KS as one design point.
