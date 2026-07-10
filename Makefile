# Simulation Makefile — run from repo root
IV = iverilog
VV = vvp
RTL = rtl/han_carlson_adder.v rtl/adder_variants.v rtl/mrpm_radix4.v rtl/mrpm_radix4_wide.v
VEC = sim/fir_vectors.txt sim/mult_vectors.txt

.PHONY: all mult fold fir pipe sweep fir16 clean

all: mult fold fir pipe fir16

mult:
	$(IV) -o build/mult.vvp rtl/han_carlson_adder.v rtl/mrpm_radix4.v sim/tb_mrpm.v
	$(VV) build/mult.vvp

fold:
	cp sim/fir_vectors.txt .
	$(IV) -o build/fold.vvp rtl/han_carlson_adder.v rtl/mrpm_radix4_wide.v rtl/fir8_fold.v sim/tb_fold.v
	$(VV) build/fold.vvp
	rm -f fir_vectors.txt

fir:
	cp sim/fir_vectors.txt .
	$(IV) -o build/fir.vvp rtl/han_carlson_adder.v rtl/mrpm_radix4_wide.v rtl/fir8_fold.v sim/tb_fir_selfcheck.v
	$(VV) build/fir.vvp
	@echo "VCD written to fir.vcd — open with: gtkwave fir.vcd &"

# TASK 1: pipelined folded FIR (deeper pipeline, latency L=4)
pipe:
	cp sim/fir_vectors.txt .
	$(IV) -o build/pipe.vvp rtl/han_carlson_adder.v rtl/mrpm_radix4_wide_pipe.v rtl/fir8_fold_pipelined.v sim/tb_fold_pipelined.v
	$(VV) build/pipe.vvp
	rm -f fir_vectors.txt

# TASK 2: functional verification of the adder sweep. The folded FIR tree
# adder is selected at compile time via -D FIR_ADDER=<module> (default HC).
# Each variant must print 0 mismatches. Synthesis metrics (LUT4/FF/Fmax/power)
# are measured separately in Gowin -> docs/adder_comparison.csv.
sweep:
	cp sim/fir_vectors.txt .
	@for A in han_carlson_adder kogge_stone_adder brent_kung_adder sklansky_adder; do \
	  echo "=== adder: $$A ==="; \
	  $(IV) -D FIR_ADDER=$$A -o build/sweep_$$A.vvp rtl/han_carlson_adder.v rtl/adder_variants.v rtl/mrpm_radix4_wide.v rtl/fir8_fold.v sim/tb_fold.v && \
	  $(VV) build/sweep_$$A.vvp; \
	done
	rm -f fir_vectors.txt

# TASK 4: 16-tap symmetric-folded FIR (8 multipliers). Vectors are generated
# by python/gencoef16.py + python/golden16.py into sim/fir16_vectors.txt.
fir16:
	cp sim/fir16_vectors.txt .
	$(IV) -o build/fir16.vvp rtl/han_carlson_adder.v rtl/mrpm_radix4_wide.v rtl/fir16_fold.v sim/tb_fir16_fold.v
	$(VV) build/fir16.vvp
	rm -f fir16_vectors.txt

clean:
	rm -rf build/*.vvp fir.vcd fir_vectors.txt fir16_vectors.txt

$(shell mkdir -p build)
