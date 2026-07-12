# Gowin Synthesis — exact steps to get every paper number

Target board: **Sipeed Tang Nano 9K**, device **GW1NR-9C** (8640 LUT4, 6480 FF).
Tool: **Gowin EDA** (FPGA Designer / IDE). You do NOT need to program the board to
get area/timing/power — synthesis + place-and-route reports are enough.

> **The RTL is already finished and verified.** The pipelined design (config C)
> and the swappable FIR-tree adder both exist and pass `make all` at 0 mismatches.
> Nothing here requires writing Verilog. Run `make all` once to reconfirm, then do
> the Gowin runs below.

---

## 0. Why DSP will read 0 (say this in the viva)

Our MRPM multiplier contains **no `*` operator** — it is built entirely from Booth
recoding, shifts (`<<<`), OR/AND/XOR logic, and parallel-prefix adders. A
synthesizer can only infer a hardware DSP/MULT block from a multiply *operator*.
So Gowin has nothing to map to a DSP, and the report will show **DSP = 0** by
construction. We still (a) keep the belt-and-suspenders option below and (b)
**verify DSP = 0 in every report**. If any run ever shows DSP ≠ 0, STOP and do not
record that run's numbers.

Belt-and-suspenders (optional): add `(* syn_multstyle = "logic" *)` immediately
before the `module mrpm_radix4` / `mrpm_radix4_wide` / `mrpm_radix4_wide_pipe`
lines. Harmless (simulation ignores it), and it forces logic even if you later
introduce a `*`. Re-run `make all` after if you add it.

---

## 1. The six synthesis runs

Config B (folded, Han-Carlson) is identical to run D-HanCarlson, so you synthesize
it **once** and use it for both. Six unique runs total:

| Run | Top module | Source files to add | Feeds analysis |
|---|---|---|---|
| **A** Direct | `fir8_symmetric` | `han_carlson_adder.v`, `mrpm_radix4.v`, `fir8_symmetric.v` | A vs B (fold saving) |
| **B** Folded (HC) | `fir8_fold` | `han_carlson_adder.v`, `mrpm_radix4_wide.v`, `fir8_fold.v` | A vs B, B vs C, D rank |
| **C** Pipelined | `fir8_fold_pipelined` | `han_carlson_adder.v`, `mrpm_radix4_wide_pipe.v`, `fir8_fold_pipelined.v` | B vs C (Fmax gain) |
| **D-KS** | `fir8_fold` | + `adder_variants.v`, macro `FIR_ADDER=kogge_stone_adder` | adder ranking |
| **D-BK** | `fir8_fold` | + `adder_variants.v`, macro `FIR_ADDER=brent_kung_adder` | adder ranking |
| **D-SK** | `fir8_fold` | + `adder_variants.v`, macro `FIR_ADDER=sklansky_adder` | adder ranking |

> **Adder-sweep caveat (important for the paper's honesty).** The `FIR_ADDER` swap
> changes only the **3 adders in the FIR summation tree**. The 12 adders *inside*
> the 4 multipliers stay Han-Carlson. So D's four variants differ in only 3 of ~15
> adders — expect **small** LUT/Fmax deltas. State this scope explicitly. If you
> want a pronounced difference, also make `mrpm_radix4_wide.v` use the `FIR_ADDER`
> macro for its A0/A1/A2 adders — that is an RTL change; re-run `make all` (must
> stay 0 mismatches) before synthesizing. Decide before you start so all D runs are
> consistent.

---

## 2. Per-run procedure (repeat for each of the six)

**2.1 Create the project**
1. `File → New → FPGA Design Project`. Name it after the run (e.g. `fir_B_fold_hc`).
2. Device selection wizard → filter **Series = GW1NR**, pick the Tang Nano 9K part:
   **GW1NR-LV9QN88PC6/I5** (GW1NR-9C, package QFN88). *Confirm against your board's
   chip marking / the Sipeed Tang Nano 9K wiki if the exact suffix differs.*

**2.2 Add sources**
3. `Project → Add Files…` → add the `.v` files from the table for this run
   (copy them out of the repo's `rtl/` folder, or add in place).
4. In the Design hierarchy, right-click the top module → **Set as Top Module**
   (top names are in the table).

**2.3 (D runs only) set the adder macro**
5. `Process` panel → right-click **Synthesize → Configuration…** → *Synthesize*
   tab → find the **"Verilog Macro"** (a.k.a. defines) field → enter e.g.
   `FIR_ADDER=kogge_stone_adder`. Make sure `adder_variants.v` is in the project.
   *Fallback if your Gowin version has no macro field:* edit the one line in
   `fir8_fold.v` — `` `define FIR_ADDER han_carlson_adder`` → the target adder name —
   synthesize, then revert. (If you edit the file, `make all` still passes since all
   four adders are functionally correct.)

**2.4 Add a clock constraint (needed for a real Fmax number)**
6. `File → New → Physical/Timing → Timing Constraints File (.sdc)`. Add one line:
   ```
   create_clock -name clk -period 10 -waveform {0 5} [get_ports {clk}]
   ```
   (10 ns = a 100 MHz *request*; the tool reports the **achievable** Fmax regardless.
   Use the same period for all six runs.)

**2.5 Guarantee no DSP**
7. `Synthesize → Configuration…` → review options; there is no universal single
   "disable DSP" checkbox, and none is needed (§0). If your version exposes a
   "use DSP / infer multiplier" option, set it to **off/logic**.

**2.6 Run the flow**
8. Double-click **Synthesize**. When it finishes, double-click **Place & Route**.
9. (Power only) `Tools → Power Analyzer` → run it on the placed-and-routed design.

---

## 3. Where to read each number (record the report filename with each value)

Reports land in the project's `impl/pnr/` folder (open from the Process panel too):

| Number | Where |
|---|---|
| **LUT4** count (÷8640 for %) | Place & Route report → *Resource Usage Summary* → "Logic / LUT" (`*.rpt.html` or `*.rpt.txt` in `impl/pnr/`) |
| **FF** count (÷6480 for %) | same report → "Register / FF" |
| **DSP/MULT** (must be 0) | same report → "DSP" or "Multiplier" row. **Verify 0.** |
| **Fmax (MHz)** | Timing report → *Max Frequency Summary* for `clk` (`*.tr.html` / Timing Analyzer view) |
| **Dynamic power (mW)** | Power Analyzer report → *Dynamic Power* (`*.power.html`) |

**Power accuracy note:** without a switching-activity file, the Power Analyzer uses
a default toggle rate. For a *fair comparison* keep the **same** toggle-rate
assumption for all six runs and state it in the paper. (Optional higher accuracy:
generate a post-P&R SAIF/VCD and load it — same for every run.)

---

## 4. After each run

- **Verify DSP = 0.** If not, STOP, do not record, add `syn_multstyle="logic"` (§0)
  and re-run.
- Paste the five numbers + their report filenames into `docs/synth_results.md`
  (skeleton already there).
- **Commit** after each passing config (per the project rule), e.g.
  `git commit -am "synth: config B folded HC — LUT/FF/Fmax/power recorded"`.

---

## 5. Filling the analysis (the point, not just numbers)

- **A vs B — real fold saving.** Compute `(LUT_A − LUT_B)/LUT_A`. It will be **< 50%**
  because fold replaces 8×(8×8) multipliers with 4×(9×8) — wider, individually more
  expensive — plus 4 nine-bit pre-adders. Attribute the gap: estimate the extra
  cost of the wider 9×8 vs 8×8 multiplier and the pre-adder LUTs, and show how they
  erode the naive 50%.
- **B vs C — pipelining.** `Fmax_C / Fmax_B` = throughput gain; `FF_C − FF_B` = the
  register cost. Report both; note latency 1→4 cycles.
- **D — adder ranking.** Rank Han-Carlson / KS / BK / Sklansky on LUT, Fmax, power.
  State plainly whether Han-Carlson actually wins at 20-bit width or whether
  Brent-Kung (fewer cells) is better here — remembering the 3-of-15-adders scope.

---

## 6. Quick checklist

```
[ ] make all → 0 mismatches (reconfirm baseline)
[ ] Run A  (fir8_symmetric)      → LUT/FF/DSP=0/Fmax/power  → commit
[ ] Run B  (fir8_fold, HC)       → …                        → commit
[ ] Run C  (fir8_fold_pipelined) → …                        → commit
[ ] Run D-KS (FIR_ADDER=kogge_stone_adder) → …              → commit
[ ] Run D-BK (FIR_ADDER=brent_kung_adder)  → …              → commit
[ ] Run D-SK (FIR_ADDER=sklansky_adder)    → …              → commit
[ ] Fill docs/synth_results.md + docs/adder_comparison.csv
[ ] Confirm every DSP cell = 0 across all six
```
