# Synthesis Results — Tang Nano 9K (GW1NR-9C)

Device budget: **8640 LUT4, 6480 FF**. Tool: Gowin EDA. DSP inference disabled;
**every run must show DSP = 0** (see `docs/GOWIN_SYNTHESIS_STEPS.md`).

> Fill each `[TBD]` from a Gowin **report file** and note the filename in the last
> column. Do NOT estimate or carry a number across configs. If a field is missing
> from a report, write "not reported" — never a guessed value.

Toggle-rate assumption for power (state once, keep identical across runs): `[TBD]`.

---

## Table 1 — All configurations

| Config | Top module | LUT4 | LUT4 % | FF | FF % | DSP (must=0) | Fmax (MHz) | Dyn power (mW) | Report files |
|---|---|---|---|---|---|---|---|---|---|
| A — Direct FIR | `fir8_symmetric` | [TBD] | [TBD] | [TBD] | [TBD] | [TBD→0] | [TBD] | [TBD] | [TBD] |
| B — Folded (Han-Carlson) | `fir8_fold` | [TBD] | [TBD] | [TBD] | [TBD] | [TBD→0] | [TBD] | [TBD] | [TBD] |
| C — Folded + pipelined | `fir8_fold_pipelined` | [TBD] | [TBD] | [TBD] | [TBD] | [TBD→0] | [TBD] | [TBD] | [TBD] |
| D — Folded, Kogge-Stone | `fir8_fold` | [TBD] | [TBD] | [TBD] | [TBD] | [TBD→0] | [TBD] | [TBD] | [TBD] |
| D — Folded, Brent-Kung | `fir8_fold` | [TBD] | [TBD] | [TBD] | [TBD] | [TBD→0] | [TBD] | [TBD] | [TBD] |
| D — Folded, Sklansky | `fir8_fold` | [TBD] | [TBD] | [TBD] | [TBD] | [TBD→0] | [TBD] | [TBD] | [TBD] |

(Config B == D-Han-Carlson; synthesize once, reuse the row values in the adder table.)

---

## Analysis 1 — Direct (A) vs Folded (B): the real fold saving

- LUT4 saving = (LUT_A − LUT_B) / LUT_A = **[TBD] %**.
- This is **less than the naive 50%** because folding trades 8×(8×8) multipliers for
  4×(9×8) multipliers (wider, individually costlier) plus 4 nine-bit pre-adders.
- Attribution (show the arithmetic):
  - Extra cost per multiplier, 9×8 vs 8×8: **[TBD] LUT4** each.
  - Pre-adder cost: 4 × 9-bit adders = **[TBD] LUT4**.
  - Net vs the ideal −50%: **[TBD]**.
- FF change A→B: **[TBD]** (both are latency-1, so expect similar).

## Analysis 2 — Folded (B) vs Pipelined (C): Fmax vs FF cost

- Fmax gain = Fmax_C / Fmax_B = **[TBD]×** ( [TBD] MHz → [TBD] MHz ).
- FF cost = FF_C − FF_B = **[TBD]** extra flip-flops.
- Latency: 1 cycle (B) → 4 cycles (C). Throughput (samples/s at Fmax): [TBD] → [TBD].
- Verdict: **[TBD]** (was the Fmax gain worth the FF/latency cost?).

## Analysis 3 — Adder ranking (D): Han-Carlson vs KS / BK / Sklansky

Scope: only the 3 FIR-tree adders differ; multiplier-internal adders stay
Han-Carlson — expect small deltas.

| Adder | LUT4 | Fmax (MHz) | Dyn power (mW) | Rank notes |
|---|---|---|---|---|
| Han-Carlson | [TBD] | [TBD] | [TBD] | |
| Kogge-Stone | [TBD] | [TBD] | [TBD] | |
| Brent-Kung | [TBD] | [TBD] | [TBD] | |
| Sklansky | [TBD] | [TBD] | [TBD] | |

- Smallest area: **[TBD]**. Highest Fmax: **[TBD]**. Lowest power: **[TBD]**.
- Does Han-Carlson actually win at 20-bit width, or is Brent-Kung better here? **[TBD]**.

---

## Comparison vs base paper [1] (Nexys A7)

| Metric | This work (Tang Nano 9K) | Base paper [1] (Nexys A7) | Notes |
|---|---|---|---|
| LUT | [TBD] | [verify against [1] Table 2] | different fabric/vendor |
| FF | [TBD] | [verify] | |
| DSP | [TBD→0] | [verify] | our claim: 0 |
| Fmax | [TBD] | [verify] | |
| Signed support | Yes | No | |

State the fabric difference (Gowin GW1NR-9 vs Xilinx Nexys A7) explicitly — LUT
counts are not 1:1 comparable across vendors; lead with the *architectural* deltas.
