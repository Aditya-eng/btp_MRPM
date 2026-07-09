# Simulation Makefile — run from repo root
IV = iverilog
VV = vvp
RTL = rtl/han_carlson_adder.v rtl/adder_variants.v rtl/mrpm_radix4.v rtl/mrpm_radix4_wide.v
VEC = sim/fir_vectors.txt sim/mult_vectors.txt

.PHONY: all mult fold fir clean

all: mult fold fir

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

clean:
	rm -rf build/*.vvp fir.vcd fir_vectors.txt

$(shell mkdir -p build)
