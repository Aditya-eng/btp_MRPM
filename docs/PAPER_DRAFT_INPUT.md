# Paper Draft Input — hand this to the writing model

**Task for the model:** write the full research-paper draft (IEEE conference style,
~6–8 pages) from the material below and the two companion files in this folder:
- `PAPER_BRIEF.md` — architecture, contributions, motivation, methodology (use for §1–§4).
- `PAPER_SKELETON.md` — section outline + reference list (use for structure + citations).

**Hard rules (do not violate):**
- Use ONLY the numbers in this file / `synth_results.md`. Do not invent or round beyond
  what is given. Every hardware number here is measured (this work) or quoted from the
  base paper PDF (base paper).
- Keep the comparison honest: the base paper measured a *standalone unsigned multiplier*;
  this work measured a *full signed FIR*. State that explicitly; do not present the rows as
  like-for-like. Carry the four caveats verbatim in spirit.
- Frame contributions as *extending* the base paper, not fixing it.

---

## 1. This work — measured results (Tang Nano 9K, GW1NR-9C; DSP=0 all runs)

| Config | LUT4 | FF | DSP | Fmax (MHz) | Dyn power (mW) |
|---|---|---|---|---|---|
| A Direct FIR (`fir8_symmetric`) | 345 | 44 | 0 | 42.858 | 2.582 |
| B Folded FIR (`fir8_fold`, HC) | 222 | 44 | 0 | 42.956 | 2.595 |
| C Folded + pipelined | 324 | 159 | 0 | 66.471 | 2.639 |
| D Kogge-Stone | 222 | 44 | 0 | 42.956 | 2.595 |
| D Brent-Kung | 223 | 44 | 0 | 41.762 | 2.595 |
| D Sklansky | 238 | 44 | 0 | 44.955 | 2.599 |

Derived: **Fold saving A→B = 35.7 % LUT4**; **Pipeline B→C = 1.55× Fmax** for +115 FF /
+102 LUT4 / latency 1→4. Adder ranking: HC≡KS smallest area (222) + lowest power; Sklansky
fastest (44.96 MHz, +4.7 %); Brent-Kung no advantage. (HC and KS are the *same* netlist —
`han_carlson_adder.v` is structurally Kogge-Stone; present as one point.) Full analysis in
`synth_results.md`. Functional: multiplier exhaustive 65,536 pairs 0 mismatches; FIR 0
mismatches vs golden (all configs).

## 2. Base paper [1] — quoted numbers (its Table 1 & Table 2)

[1] Guru Siva Subramanian V., D. S. T.N., Aditya S., "A low cost area-efficient modified
Russian peasant multiplier (MRPM) for biomedical applications," *Integration, the VLSI
Journal*, vol. 104, 102474, 2025.

Design: **8-bit *unsigned* iterative MRPM** + Kogge-Stone adder, on **Nexys A7 (XC7A100T:
63,400 LUT / 126,800 FF / 15,850 slices)**.

**Table 1 (proposed MRPM):** Max clock 0.714 MHz · Slice LUTs 68 · Slice Registers 58 ·
Slices 24 · Dynamic power 1.136 W · Critical-path delay 17.217 ns · Bonded IOB 36 · 215 nets.

**Table 2 (8-bit multiplier LUT comparison):** Proposed MRPM 68 · Vedic [4] 114 (7.159 ns) ·
Array [4] 116 (9.5 ns) · Booth [4] 118 (6.92 ns) · Vedic+Kogge-Stone [17] 309 (5.588 ns) ·
Reduced-complexity Wallace SORTCSLA [6] 224 (21.499 ns, 0.264 W) · Modified Wallace [18]
(9.438 ns, 3.92 W).

## 3. The comparison to write (with caveats)

Reproduce the comparison table and caveats from `synth_results.md` §"Comparison vs base
paper". Lead the Results/Discussion with the **architectural deltas** (the gaps the base
paper leaves), each now backed by data or structure:

| Delta vs [1] | Evidence |
|---|---|
| Signed operation | signed radix-4 Booth; 65,536-pair exhaustive 0-mismatch |
| Parallel (not iterative) multiplier | Fmax 42.96/66.47 MHz vs their 0.714 MHz (arch, not tuning) |
| Symmetric fold (fewer multipliers) | 4 vs 8 mults; 35.7 % LUT4 saving A→B, bit-identical |
| Pipelining option | 1.55× Fmax, +115 FF, latency 1→4 |
| Prefix-adder sweep on one fabric | HC/KS/BK/Sklansky measured (Table above) |
| LUT-only, DSP-free | DSP=0 confirmed on all runs |

**Do NOT claim** a power win (their 1.136 W vs our 2.595 mW is a methodology mismatch) or a
clean LUT win (multiplier-vs-FIR, different fabric). Recommend one extra run —
standalone `mrpm_radix4` (8×8) on this flow — to enable a true multiplier-to-multiplier
comparison against their 68 LUT / 0.714 MHz.

## 4. Abstract order (lead with deltas)

signed support → radix-4 (4 PPs) → symmetric fold (4 vs 8 mults, bit-exact) → pipeline
(1.55× Fmax) → LUT-only DSP=0 on Tang Nano 9K → one line on ECG/EEG applicability.
State exact accuracy (multiplier verified over all 65,536 pairs).

## 5. Figures/assets available

RTL in `rtl/`; golden + coeffs in `python/`; `make fir` → `fir.vcd` (GTKWave waveform, the
Fig-5 equivalent); coefficient/response plots from `python/gencoef.py`; tables from
`synth_results.md` and `adder_comparison.csv`.
