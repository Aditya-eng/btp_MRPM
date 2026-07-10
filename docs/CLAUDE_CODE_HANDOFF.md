# Handoff to Claude Code — MRPM FIR project (BTP Part 1)

You are continuing a verified hardware project. Read this fully before editing.

## What this project is
An 8-bit signed radix-4 modified-RPM (Booth) multiplier with Han-Carlson adders,
used to build an 8-tap linear-phase FIR filter for biomedical (ECG/EEG) signal
processing. Target board: Sipeed Tang Nano 9K (Gowin GW1NR-9, 8640 LUT4, 6480 FF).
This is Part 1 (filter). Part 2 (real ECG/EEG denoising) comes later.

## What is DONE and VERIFIED (do not redo, do not "improve" silently)
1. `rtl/han_carlson_adder.v` — parameterized prefix adder. Correct.
2. `rtl/mrpm_radix4.v` — 8x8 signed Booth MRPM. Bit-exact vs a*b over all 65536 pairs.
3. `rtl/mrpm_radix4_wide.v` — parameterized AW x BW version (used by folded FIR).
4. `rtl/fir8_symmetric.v` — 8-tap FIR, naive (8 multipliers). Bit-exact.
5. `rtl/fir8_fold.v` — 8-tap FIR, SYMMETRIC-FOLDED (4 multipliers). Bit-exact.
   This is the headline area result: half the multipliers, identical output.
6. `rtl/adder_variants.v` — Kogge-Stone, Brent-Kung, Sklansky. All functionally correct.
7. `python/golden.py` — golden model; `python/gencoef.py` — coefficient generation.
8. Coeffs: h=[0,3,20,42,42,20,3,0], scale 2^7, fs=250Hz, 40Hz LPF, Hamming sinc.

Run `make all` — every testbench must print "0 mismatches". If not, STOP and report.

## What is NOT done (your work, in priority order)
### TASK 1 — Pipeline the folded FIR (fir8_fold.v -> fir8_fold_pipelined.v)
Insert pipeline registers at 4 boundaries: (1) delay line [exists], (2) after
multipliers, (3) after first adder-tree level, (4) output [exists]. Also register
inside mrpm_radix4_wide between Booth-PP generation and final accumulation.
Goal: raise Fmax. Verify: same 0-mismatch, account for the extra latency cycles
in the testbench (currently assumes 1-cycle latency; pipelined will be ~4).

### TASK 2 — Adder sweep on Gowin
For EACH adder (Han-Carlson, KS, BK, Sklansky): build the folded FIR with that
adder, synthesize in Gowin, record LUT4 / FF / Fmax / dynamic power. Produce
docs/adder_comparison.csv. Swap adders by editing the module instantiation name
in fir8_fold.v (all four share the same port list).

### TASK 3 — Gowin synthesis, DSP DISABLED (critical)
The GW1NR-9 has hardware DSP multipliers. The whole thesis is LUT-based efficiency.
You MUST prevent DSP inference or the "area-efficient LUT multiplier" claim is void.
In Gowin: set synthesis option to disable DSP/multiplier inference (or use a
(* syn_multstyle = "logic" *) attribute on the multiplier module). Confirm the
utilization report shows 0 DSP blocks used. Record LUT4/FF/Fmax/power into
docs/synth_results.md. Compare against the base paper's Table 2 (Nexys A7 numbers).

### TASK 4 — Extend to 16-tap (optional, strengthens paper)
Same fold pattern, 8 multipliers instead of 4. Regenerate coeffs for 16 taps in
gencoef.py (change N=16), re-verify golden, build fir16_fold.v.

## Rules
- Never claim a result you didn't measure. LUT/Fmax/power come from Gowin reports only.
- Every RTL change must keep "make all" at 0 mismatches.
- Commit after each passing task with a clear message.
- The base paper is docs/ references; frame contributions as extending it, not "fixing errors".
