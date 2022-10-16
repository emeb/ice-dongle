# Makefile for icestorm tools + yosys + nextpnr
# Modified from examples in icestorm distribution
# 01-16-18 E. Brombaugh

SRC = osc_tst.v

# project stuff
PROJ = osc_tst
PIN_DEF = ice-dongle.pcf
DEVICE = up5k
PACKAGE = sg48

TOOLS = /opt/openfpga/fpga-toolchain
YOSYS = $(TOOLS)/bin/yosys
NEXTPNR = $(TOOLS)/bin/nextpnr-ice40
#NEXTPNR_ARGS = --pre-pack $(SDC)
ICEPACK = $(TOOLS)/bin/icepack
ICETIME = $(TOOLS)/bin/icetime
ICEPROG = $(TOOLS)/bin/iceprog
ICEBRAM = $(TOOLS)/bin/icebram
CDCPROG = cdc_prog
VERILATOR = verilator
TECH_LIB = $(TOOLS)/share/yosys/ice40/cells_sim.v

all: $(PROJ).bin

%.json: $(SRC)
	$(YOSYS) -p 'synth_ice40 -top $(PROJ) -json $@' $(SRC)

%.asc: %.json $(PIN_DEF) 
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PIN_DEF) --asc $@
		
%.bin: %.asc
	$(ICEPACK) $< $@

%.rpt: %.asc
	$(ICETIME) -d $(DEVICE) -mtr $@ $<

# original FTDI-based programmer
#prog: $(PROJ).bin
#	$(ICEPROG) -S $<

# my custom STM32F042-based programmer - direct to FPGA
prog: $(PROJ).bin
	$(CDCPROG) -p /dev/ttyACM0 $<

# my custom STM32F042-based programmer - write to SPI flash
flash: $(PROJ).bin
	$(CDCPROG) -p /dev/ttyACM0 -w $<

lint: $(SRC)
	$(VERILATOR) --lint-only -Wall --top-module $(PROJ) $(TECH_LIB) $(SRC)

clean:
	rm -f *.json *.asc *.rpt *.bin *.hex

.SECONDARY:
.PHONY: all prog clean
