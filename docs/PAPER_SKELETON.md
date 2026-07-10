# [PAPER SKELETON] Pipelined Signed Radix-4 MRPM with Han-Carlson Adder for ECG/EEG FIR Filtering

Authors: [Author], [co-authors], [advisor]
Target venue: IEEE conference (ISVLSI / VLSID / iSES) or Integration journal.

---

## Abstract (write last; ~200 words)
Lead with quantified results in this order: (1) multiplier iteration reduction
(radix-4: 4 vs 8), (2) FIR multiplier reduction (symmetric fold: 4 vs 8),
(3) LUT/FF utilization on Tang Nano 9K, (4) Fmax, (5) power. State signed support
and full accuracy (exact multiplier). One sentence on ECG/EEG applicability.
Mirror the base paper's abstract structure but lead with YOUR deltas.

## 1. Introduction
- Motivation: biomedical devices need area+power efficiency (same as base paper).
- ADD the gap the base paper leaves: iterative RPM is inherently slow (8 iterations
  for 8-bit); bolting a fast adder onto a sequential loop optimizes the wrong term.
- ADD: base paper is unsigned only; biomedical differential signals need signed.
- State contributions as a bulleted list (5 items from README).

## 2. Related Works
- Cite the base paper [ref 1 below] as the direct predecessor. Position honestly:
  it demonstrates MRPM+Kogge-Stone but (a) reports unreconciled speed metrics,
  (b) is unsigned, (c) does not exploit radix-4 recoding or symmetric folding.
- Cite the base paper's own references where you build on them (Booth, Wallace,
  Vedic, Kogge-Stone, Han-Carlson [ref 9], symmetric FIR).
- Frame as "gaps," not "errors."

## 3. Proposed Architecture
### 3.1 Signed radix-4 Booth MRPM
- Booth recoding: 2 multiplier bits/step, digits {-2,-1,0,+1,+2}, 4 steps.
- Include Algorithm 1 (pseudocode from docs/, replaces base paper's Algorithm 1).
- Fig: radix-4 MRPM datapath (Booth stages -> Han-Carlson tree).
### 3.2 Han-Carlson adder
- Hybrid KS/BK prefix; depth log2(N)+1; balance of area vs speed.
### 3.3 Symmetric-folded FIR
- Linear-phase h[i]=h[7-i]; pre-add pairs; 4 multipliers not 8.
- Preserves QRS morphology (linear phase). Fig: folded FIR structure.
### 3.4 Pipelining
- 4-stage pipeline; latency vs throughput. Fig: pipeline boundaries.

## 4. Implementation
- Tool: open-source (Icarus + GTKWave for sim) + Gowin EDA for synthesis.
- Board: Tang Nano 9K, GW1NR-9. NOTE: DSP inference disabled to force LUT logic.
- Verification: exhaustive multiplier (65536 pairs), golden-model FIR (0 mismatches).
- Fig: GTKWave simulation waveform (your Fig-5 equivalent, signed decimal format).

## 5. Results and Discussion
### 5.1 Functional verification (0 mismatches — tables).
### 5.2 Resource utilization (LUT4/FF/DSP=0) vs base paper Table 2.
### 5.3 Adder comparison (Han-Carlson vs KS/BK/Sklansky) — your novel table.
### 5.4 Timing (Fmax) and power.
### 5.5 Area-delay tradeoff discussion.

## 6. Conclusion + Future Work
- Summarize deltas. Part 2 teaser: real ECG/EEG denoising, signed differential.

---

## References (from base paper — reuse the ones you build on; renumber for your paper)

[1] G. S. Subramanian V., D. S. T.N., Aditya S., "A low cost area-efficient modified
    Russian peasant multiplier (MRPM) for biomedical applications," Integration,
    the VLSI Journal, vol. 104, 102474, 2025. doi:10.1016/j.vlsi.2025.102474
    [THE BASE PAPER]

[2] S. S. Lotfabadi, A. Ye, S. Krishnan, "Measuring the power efficiency of
    sub-threshold FPGAs for implementing portable biomedical applications,"
    Microprocess. Microsyst., vol. 36, no. 3, pp. 151-158, 2012.

[3] A. Ajay, R. M. Lourde, "VLSI implementation of an improved multiplier for FFT
    computation in biomedical applications," IEEE CSAS on VLSI, 2015, pp. 68-73.

[4] A. Phuse, P. Tasgaonkar, "Design and implementation of different multiplier
    techniques and efficient MAC unit on FPGA," ICONSIP, 2022, pp. 1-5.

[5] A. S. Prabhu, V. Elakya, "Design of modified low power booth multiplier,"
    ICCCA, 2012, pp. 1-6.

[6] C. U. Kumar, B. J. Rabi, "Design and implementation of modified Russian Peasant
    multiplier using MSQRTCSLA based FIR filter," Indian J. Sci. Technol., vol. 9,
    no. 7, 2016.

[7] G. R. Gokhale, P. D. Bahirgonde, "Design of Vedic-multiplier using area-efficient
    Carry Select Adder," ICACCI, 2015, pp. 576-581.

[8] Y. Bansal, C. Madhu, P. Kaur, "High speed Vedic multiplier designs — a review,"
    RAECS, 2014, pp. 1-6.

[9] E. J. Rao, T. Ramanjaneyulu, K. J. Kumar, "Advanced multiplier design and
    implementation using Han-Carlson adder," ICONIC, 2018, pp. 1-5.
    [KEY: Han-Carlson + MRPM precedent — cite when justifying your adder choice]

[10] S. Dhole, S. Shembalkar, T. Yadav, P. Thakre, "Design and FPGA implementation
     of 4x4 Vedic multiplier using different architectures," IJERT, vol. 6, no. 4, 2017.

[11] U. Penchalaiah, S. K. VG, "Design of high-speed and energy-efficient parallel
     prefix Kogge-Stone adder," ICSCAN, 2018, pp. 1-7.

[12] A. Raju, S. K. Sa, "Design and performance analysis of multipliers using
     Kogge-Stone adder," ICATccT, 2017, pp. 94-99.

[13] K. Gunasekaran, M. Manikandan, "High speed reconfigurable FIR filter using
     Russian Peasant Multiplier with Sklansky adder," RJASET, vol. 8, no. 24,
     pp. 2451-2456, 2014.
     [KEY: RPM-based FIR precedent — cite in FIR section]

[14] P. Paz, M. Garrido, "Efficient implementation of complex multipliers on FPGAs
     using DSP slices," J. Signal Process. Syst., vol. 95, no. 4, pp. 543-550, 2023.
     [Cite when justifying WHY you avoid DSP slices]

[15] B. Khurshid, "FPGA-based resource-optimal approximate multiplier for
     error-resilient applications," Int. J. Circuit Theory Appl., 2024.

[16] A. K, S. Sushma, V. S. Teja, "Improving error resilience in FPGA-based
     multi-level approximate multipliers using modified full adders," DICCT, 2025,
     pp. 153-158.

[17] R. Anjana et al., "Implementation of Vedic multiplier using Kogge-Stone adder,"
     ICES, 2014, pp. 28-31.

[18] S. Abed, B. J. Mohd, Z. Al-bayati, S. Alouneh, "Low power Wallace multiplier
     design based on wide counters," Int. J. Circuit Theory Appl., vol. 40, no. 11,
     pp. 1175-1185, 2012.

[19] A. Badawi et al., "FPGA realization and performance evaluation of fixed-width
     modified Baugh-Wooley multiplier," TAEECE, 2015, pp. 155-158.

## New references YOU must add (not in base paper)
[20] Sipeed, "Tang Nano 9K datasheet / GW1NR-9 (8640 LUT4, 6480 FF)," 2023.
[21] [ECG/EEG signal source — e.g. MIT-BIH Arrhythmia Database, PhysioNet] for Part 2.
[22] [Any open-source Gowin/Yosys toolchain citation if you use it.]
