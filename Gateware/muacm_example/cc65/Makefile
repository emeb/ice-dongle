# Makefile for cc65 to verilog hex
# 03-04-19 E. Brombaugh

# C and assy source files
SRC =	init.s util.s acia.s spi.s cmon.s basic.s video.s key.s

# compiler output
OBJ = rom

# build tools & options
CL65 = cl65
CLFLAGS  = -t none -O --cpu 65c02 -C sbc.cfg -m $(OBJ).map -l $(OBJ).lst
HEXDUMP = hexdump
HEXDUMP_ARGS = -v -e '1/1 "%02x " "\n"'

# Targets
all: $(OBJ).hex

$(OBJ).hex: $(OBJ)
	$(HEXDUMP) $(HEXDUMP_ARGS) $< > $@

$(OBJ): $(SRC)
	$(CL65) $(CLFLAGS) -o $(OBJ) $(SRC)

clean:
	-rm -f *.o $(OBJ) $(OBJ).hex $(OBJ).map $(OBJ).lst

