# Area-Efficient Signed Radix-4 MRPM FIR Filter for Biomedical Applications

8-bit signed radix-4 modified Russian Peasant (Booth) multiplier with Han-Carlson
adders, applied to an 8-tap linear-phase FIR filter. Target: Tang Nano 9K (Gowin GW1NR-9).

Extends: Guru Siva Subramanian V. et al., "A low cost area-efficient modified Russian
peasant multiplier (MRPM) for biomedical applications," Integration 104 (2025) 102474.

## Contributions over the base paper
- Radix-4 Booth recoding: 4 iterations instead of 8 (halved).
- Signed multiplication (base paper is unsigned-only).
- Symmetric-folded FIR: 4 multipliers instead of 8, bit-identical output.
- Han-Carlson adder + comparison sweep vs Kogge-Stone / Brent-Kung / Sklansky.
- Open-source flow on Tang Nano 9K.

## Verified status
| Block | Verification | Result |
|-------|-------------|--------|
| Signed radix-4 MRPM (8x8) | exhaustive, all 65536 pairs | 0 mismatches |
| Symmetric-folded 8-tap FIR | vs Python golden, 63 samples | 0 mismatches |
| All 4 adders | cross-check vs addition | 0 errors |

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

## Next steps
See `docs/CLAUDE_CODE_HANDOFF.md` — pipeline, Gowin synthesis (DSP disabled), adder sweep.
