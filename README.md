# An Area-Efficient Pipelined Signed Radix-4 MRPM for Biomedical FIR Filtering

8-bit signed radix-4 modified Russian Peasant (Booth) multiplier with parallel-prefix
adders, applied to a pipelined 8-tap symmetric-folded linear-phase FIR filter.
Target: Tang Nano 9K (Gowin GW1NR-9C).

Extends: Guru Siva Subramanian V. et al., "A low cost area-efficient modified Russian
peasant multiplier (MRPM) for biomedical applications," Integration 104 (2025) 102474.

**Full paper draft: [`docs/paper/paper.tex`](docs/paper/paper.tex) (compiled:
[`docs/paper/paper.pdf`](docs/paper/paper.pdf)).**

## Contributions over the base paper (measured, Gowin GW1NR-9C, DSP=0 confirmed)
- Radix-4 Booth recoding: 4 partial products instead of ~8 sequential iterations.
- Signed multiplication (base paper is unsigned-only).
- Symmetric-folded FIR: 4 multipliers instead of 8 → **345→222 LUT4, a 35.7% saving**,
  bit-identical output.
- 4-stage pipeline: **1.55× Fmax** (42.96→66.47 MHz) for +115 FF, +102 LUT4.
- Prefix-adder sweep (Kogge-Stone/Brent-Kung/Sklansky, Han-Carlson≡Kogge-Stone on this
  RTL): area/Fmax/power span only ~7% — the structural levers (fold, pipeline) dominate.
- Honest counterpoint: the **standalone** 8×8 multiplier alone is *larger* than the base
  paper's (170 vs 68 LUT) — the price of signed + parallel evaluation, recovered at the
  filter level by coefficient specialization + folding. See `docs/synth_results.md`.
- LUT-only implementation, DSP inference disabled, 0 DSP blocks confirmed on every run.

## Verified status
| Block | Verification | Result |
|-------|-------------|--------|
| Signed radix-4 MRPM (8x8) | exhaustive, all 65536 pairs | 0 mismatches |
| Symmetric-folded 8-tap FIR | vs Python golden, 63 samples | 0 mismatches |
| Pipelined folded FIR (4-stage) | vs Python golden, latency-4 | 0 mismatches |
| All 4 adder variants | vs Python golden | 0 mismatches |
| Gowin synthesis (6 configs) | LUT4/FF/DSP/Fmax/power | DSP=0 all runs — see `docs/synth_results.md` |

## Quick start
```
make all          # runs all testbenches, expect "0 mismatches"
make fir          # generates fir.vcd
gtkwave fir.vcd & # view waveform
```

## Layout
- `rtl/`    synthesizable Verilog
- `sim/`    testbenches + golden vectors
- `python/` golden model + coefficient generation
- `docs/`   handoff notes, paper, results
- `gowin/`  Gowin project files (added during synthesis)

## Status
Pipeline, Gowin synthesis (DSP disabled), and the adder sweep are complete — see
`docs/synth_results.md` for numbers and `docs/paper/paper.tex` for the full writeup.
`docs/CLAUDE_CODE_HANDOFF.md` is kept as historical planning context.

## Next steps
See `docs/paper/paper.tex` header comment for remaining pre-submission TODOs
(author affiliations/emails, optional waveform figure, final reference re-check).
