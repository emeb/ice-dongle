# Makefile for riscv_lcd raw image flashing
# Modified from examples in icestorm distribution
# 10-15-22 E. Brombaugh

IMG = ice-dongle_clip

# tools
IMGCVT = png2rgb565.sh
FFMPEG = ffmpeg
DD = dd
CDCPROG = cdc_prog

all: $(IMG).565

%.565: %.png
	$(FFMPEG) -vcodec png -i $< -vcodec rawvideo -f rawvideo -pix_fmt rgb565 temp.565
	$(DD) conv=swab < temp.565 > $@
	rm temp.565

flash: $(IMG).565
	$(CDCPROG) -w -a 0x200000 -p /dev/ttyACM0 $<
	
clean:
	rm -f *.565

.SECONDARY:
.PHONY: all prog clean
