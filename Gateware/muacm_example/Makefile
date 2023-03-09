PROJ := acm-loopback

BOARD   ?= ice-dongle
PCF     := data/top-$(BOARD).pcf

H := \#
DEVICE  := $(shell awk '/$(H)$(H) dev:/{print $$3; exit 1}' $(PCF) && echo up5k)
PACKAGE := $(shell awk '/$(H)$(H) pkg:/{print $$3; exit 1}' $(PCF) && echo sg48)

SRCS_acm-loopback = $(addprefix rtl/, \
	rgb_driver.v \
	dfu_helper.v \
	fifo_sync_shift.v \
	muacm_xclk.v \
	sysmgr_hfosc.v \
	sysmgr_pll.v \
	cpu_system.v \
	cpu_65c02.v \
	ALU.v \
	usb_acia.v \
	ram_32kb.v \
	system_bus.v \
	wishbone.v \
	top.v \
)
TOPMOD := top

MUACM_ILANG := ip/muacm.ilang

# preparing the machine code
FAKE_HEX =	rom.hex
REAL_HEX =  code.hex

#TOOLDIR  := /opt/openfpga/oss-cad-suite_05-18-2022/bin
TOOLDIR  := /opt/openfpga/oss-cad-suite_03-09-2023/bin
YOSYS    := $(TOOLDIR)/yosys
NEXTPNR  := $(TOOLDIR)/nextpnr-ice40
ICEPACK  := $(TOOLDIR)/icepack
ICEBRAM  := $(TOOLDIR)/icebram
CDCPROG = cdc_prog
DFU_UTIL := dfu-util

BOARD_DEFINE := BOARD_$(shell echo $(BOARD) | tr a-z\- A-Z_)
YOSYS_READ_ARGS  := -D$(BOARD_DEFINE)=1
YOSYS_SYNTH_ARGS :=
NEXTPNR_ARGS := --no-promote-globals

all: $(PROJ).bin

$(FAKE_HEX):
	$(ICEBRAM) -g 8 2048 > $(FAKE_HEX)

%.json %.synth.log: $(MUACM_ILANG) $(SRCS_$(PROJ)) $(FAKE_HEX)
	$(YOSYS) -L $*.synth.log -p 'read_verilog $(YOSYS_READ_ARGS) $(SRCS_$(PROJ)); read_ilang $(MUACM_ILANG); synth_ice40 $(YOSYS_SYNTH_ARGS) -top $(TOPMOD) -json $*.json'

%.asc %.pnr.log: $(PCF) %.json
	$(NEXTPNR) $(NEXTPNR_ARGS) --$(DEVICE) --package $(PACKAGE) --json $*.json --pcf $(PCF) --log $*.pnr.log --asc $*.asc

$(REAL_HEX):
	$(MAKE) -C cc65/ rom.hex
	cp cc65/rom.hex ./$(REAL_HEX)
		
%.bin: %.asc $(REAL_HEX)
	$(ICEBRAM) $(FAKE_HEX) $(REAL_HEX) < $< > temp.asc
	$(ICEPACK) temp.asc $@

%.ilang: %.ilang.bz2
	bzcat $< > $@

prog: $(PROJ).bin
	$(CDCPROG) -p /dev/ttyACM0 $<

recode:
	rm -f $(REAL_HEX) $(PROJ).bin
	$(MAKE) prog
    
flash: $(PROJ).bin
	$(CDCPROG) -w -p /dev/ttyACM0 $<

dfu: $(PROJ).bin
	$(DFU_UTIL) -a 0 -R -D $<

clean:
	$(MAKE) -C cc65/ clean
	rm -f *.json *.asc *.bin *.log *.hex

.PHONY: all clean
.PRECIOUS: %.ilang %.json %.asc %.bin
