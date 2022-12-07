# Makefile for icestorm tools + yosys + nextpnr
# Modified from examples in icestorm distribution
# 01-16-18 E. Brombaugh

# src directory
VPATH = ../src

SRC =	../src/top.v ../src/tst_6502.v ../src/acia.v ../src/acia_rx.v \
		../src/acia_tx.v ../verilog-6502/cpu_65c02.v ../verilog-6502/ALU.v

# preparing the machine code
FAKE_HEX =	rom.hex
REAL_HEX =  code.hex

# project stuff
PROJ = top
PIN_DEF = ../src/ice-dongle.pcf
SDC = ../src/top.sdc
DEVICE = up5k
PACKAGE = sg48

# tools
TOOLS = /opt/openfpga/fpga-toolchain
YOSYS = $(TOOLS)/bin/yosys
YOSYS_SYNTH_ARGS = -dsp -dff -abc9 -no-rw-check
NEXTPNR = $(TOOLS)/bin/nextpnr-ice40
NEXTPNR_ARGS = --pre-pack $(SDC) --placer heap --timing-allow-fail
ICEPACK = $(TOOLS)/bin/icepack
ICETIME = $(TOOLS)/bin/icetime
ICEPROG = $(TOOLS)/bin/iceprog
ICEBRAM = $(TOOLS)/bin/icebram
CDCPROG = cdc_prog
DFU_UTIL = dfu-util
VERILATOR = verilator
TECH_LIB = $(TOOLS)/share/yosys/ice40/cells_sim.v

all: $(PROJ).bin

$(FAKE_HEX):
	$(ICEBRAM) -g 8 4096 > $(FAKE_HEX)

%.json: $(SRC) $(FAKE_HEX)
	$(YOSYS) -p 'synth_ice40 -dsp -top $(PROJ) -json $@' $(SRC)

%.asc: %.json $(PIN_DEF) 
	$(NEXTPNR) $(NEXTPNR_ARGS) --$(DEVICE) --json $< --pcf $(PIN_DEF) --package $(PACKAGE) --asc $@

$(REAL_HEX):
	$(MAKE) -C ../cc65/ rom.hex
	cp ../cc65/rom.hex ./$(REAL_HEX)
		
%.bin: %.asc $(REAL_HEX)
	$(ICEBRAM) $(FAKE_HEX) $(REAL_HEX) < $< > temp.asc
	$(ICEPACK) temp.asc $@

%.rpt: %.asc
	$(ICETIME) -d $(DEVICE) -mtr $@ $<

prog: $(PROJ).bin
	$(CDCPROG) -p /dev/ttyACM0 $<

recode:
	rm -f $(REAL_HEX) $(PROJ).bin
	$(MAKE) prog
    
flash: $(PROJ).bin
	$(CDCPROG) -w -p /dev/ttyACM0 $<

dfu: $(PROJ).bin
	$(DFU_UTIL) -a 0 -R -D $<

lint: $(SRC)
	$(VERILATOR) --lint-only -Wall -DNO_ICE40_DEFAULT_ASSIGNMENTS --top-module $(PROJ) $(TECH_LIB) $(SRC)

clean:
	$(MAKE) -C ../cc65/ clean
	rm -f *.json *.asc *.rpt *.bin *.hex

.SECONDARY:
.PHONY: all prog clean
