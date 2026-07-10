# GitHub repo setup

## One-time
```
cd <this-repo>
git init
git add .
git commit -m "Part 1: verified signed radix-4 MRPM + symmetric-folded 8-tap FIR"
git branch -M main
git remote add origin https://github.com/<you>/mrpm-fir-biomedical.git
git push -u origin main
```
(Create the empty repo on github.com first, no README, then the commands above.)

## Suggested commit cadence going forward
- After pipelining passes: "Add 4-stage pipelined folded FIR"
- After each adder synthesized: "Gowin synth: <adder> results"
- After DSP-disabled synthesis: "Force LUT logic, confirm 0 DSP blocks"
- Tag the version you submit: git tag btp-part1-submit

## What's tracked vs ignored
Tracked: all rtl/, sim/ (incl. golden vectors), python/, docs/, Makefile.
Ignored: build artifacts, *.vcd, *.vvp, Gowin impl/, bitstreams (see .gitignore).
