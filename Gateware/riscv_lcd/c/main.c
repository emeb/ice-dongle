/*
 * main.c - top level of picorv32 firmware
 * 06-30-19 E. Brombaugh
 */

#include <stdio.h>
#include "riscv_lcd.h"
#include "acia.h"
#include "printf.h"
#include "spi.h"
#include "flash.h"
#include "psram.h"
#include "clkcnt.h"
#include "st7789.h"
#include "i2c.h"
#include "cmd.h"

/* build time */
const char *bdate = __DATE__;
const char *btime = __TIME__;
const char *fwVersionStr = "V0.1";

/*
 * simple text output to graphics
 */
uint8_t gline = 0;
static void putcp(void* p,char c)
{
    *(*((char**)p))++ = c;
}
void gprintf(char *fmt, ...)
{
	char s[32], *h = s;
    va_list va;
    va_start(va,fmt);
    tfp_format(&h,putcp,fmt,va);
    putcp(&h,0);
    va_end(va);
	st7789_drawstr(0, 8*gline++, s, ST7789_WHITE, ST7789_BLACK);
}

/*
 * main
 */
void main()
{
	uint32_t cnt, spi_id, i, j;
	char gbuf[32];
	//int c;
	
	init_printf(0, acia_printf_putc);
	printf("\n\n\r-----------------------------\n\r");
	printf("riscv_lcd - starting up\n\r");
    printf("Version: %s\n\r", fwVersionStr);
    printf("Build Date: %s\n\r", bdate);
    printf("Build Time: %s\n\r", btime);
	printf("-----------------------------\n\r");

	/* test both SPI ports */
	spi_init(SPI0);
	spi_init(SPI1);
	
#if 0
	/* Init LCD */
	st7789_init(SPI1);
	printf("LCD initialized\n\r");
#endif

#if 0
	/* test lcd text */
	for(i=0;i<40;i++)
	{
		gprintf("Line %d", i);
	}
#endif

#if 0
	/* get spi flash id */
	flash_init(SPI0);	// wake up the flash chip
	spi_id = flash_id(SPI0);
	printf("spi flash id: 0x%08X\n\r", spi_id);
	gprintf("SPI Flash Test...");
	gprintf("ID: 0x%08X", spi_id);
	
	/* read some data */
	{
		uint8_t read[128];
		flash_read(SPI0, read, 0x200000, 128);
		for(i=0;i<128;i+=4)
		{
			gprintf("%02X: %02X %02X %02X %02X", i, read[i], read[i+1], read[i+2], read[i+3] );
		}
	}
#endif

#if 0
	/* get spi psram id */
	spi_id = psram_id(SPI0);
	printf("spi psram id: 0x%08X\n\r", spi_id);
	gprintf("SPI PSRAM Test...");
	gprintf("ID: 0x%08X", spi_id);
	
	/* read some data */
	{
		uint8_t read[128];
		psram_read(SPI0, read, 0, 128);
		gprintf("read");
		for(i=0;i<16;i+=4)
		{
			gprintf("%02X: %02X %02X %02X %02X", i, read[i], read[i+1], read[i+2], read[i+3] );
		}
		
		gprintf("write");
		for(i=0;i<16;i++)
			read[i] = i<<4 | 0xf;
		for(i=0;i<16;i+=4)
		{
			gprintf("%02X: %02X %02X %02X %02X", i, read[i], read[i+1], read[i+2], read[i+3] );
		}
		psram_write(SPI0, read, 0, 128);
		
		gprintf("zero");
		for(i=0;i<16;i++)
			read[i] = 0;
		for(i=0;i<16;i+=4)
		{
			gprintf("%02X: %02X %02X %02X %02X", i, read[i], read[i+1], read[i+2], read[i+3] );
		}
		
		psram_read(SPI0, read, 0, 128);
		gprintf("re-read");
		for(i=0;i<16;i+=4)
		{
			gprintf("%02X: %02X %02X %02X %02X", i, read[i], read[i+1], read[i+2], read[i+3] );
		}
	}
#endif

#if 0
	/* test limits */
	st7789_fillScreen(ST7789_BLACK);
#define XMIN 0
#define XMAX st7789_width()
#define YMIN 0
#define YMAX st7789_height()
	st7789_drawFastVLine(XMIN, YMIN, YMAX, ST7789_WHITE);
	st7789_drawFastVLine(XMAX-1, YMIN, YMAX, ST7789_WHITE);
	st7789_drawFastHLine(XMIN, YMIN, XMAX-XMIN, ST7789_WHITE);
	st7789_drawFastHLine(XMIN, YMAX-1, XMAX-XMIN, ST7789_WHITE);
	st7789_drawLine(XMIN, YMIN, XMAX, YMAX, ST7789_WHITE);
	st7789_drawLine(XMAX, YMIN, XMIN, YMAX, ST7789_WHITE);
	//st7789_drawstr(XMAX/2-44, (YMAX/2-4), "Hello World",
	//	ST7789_WHITE, ST7789_BLACK);
#endif
	
#if 0
	/* color fill + text fonts */
	printf("Color Fill & Fonts\n\r");
	st7789_fillScreen(ST7789_MAGENTA);
	st7789_drawstr(st7789_width()/2-44, (st7789_height()/2-12*8), "Hello World", ST7789_WHITE, ST7789_MAGENTA);
	
	/* test font */
	for(i=0;i<256;i+=16)
		for(j=0;j<16;j++)
			st7789_drawchar((st7789_width()/2-8*8)+(j*8), (st7789_height()/2-8*8)+(i/2), i+j,
				ST7789_GREEN, ST7789_BLACK);
	
	clkcnt_delayms(1000);
#endif
	
#if 0
	/* test colored lines */
	printf("Colored Lines\n\r");
	{
		uint8_t rgb[3], hsv[3];
		uint16_t color;
		st7789_fillScreen(ST7789_BLACK);
		hsv[1] = 255;
		hsv[2] = 255;
		j=256;
		while(j--)
		{	
			for(i=0;i<st7789_width();i++)
			{
				hsv[0] = (i+j);
				
				st7789_hsv2rgb(rgb, hsv);
				color = st7789_Color565(rgb[0],rgb[1],rgb[2]);
		#if 1
				/* rotating box */
				st7789_drawLine(i, 0, st7789_width()-1, i, color);
				st7789_drawLine(st7789_width()-1, i, st7789_width()-1-i, st7789_width()-1, color);
				st7789_drawLine(st7789_width()-1-i, st7789_width()-1, 0, st7789_width()-1-i, color);
				st7789_drawLine(0, st7789_width()-1-i, i, 0, color);
		#else
				/* slow downward motion */
				st7789_drawFastHLine(0, i, st7789_width(), color);
		#endif
			}
		}
	}
	clkcnt_delayms(1000);
#endif

#if 0
	/* test image blit from flash */
	{
		flash_init(SPI0);	// wake up the flash chip
		uint16_t blit[ST7789_TFTWIDTH*4];
		uint32_t blitaddr, blitsz;
		blitaddr = 0xa0000;
		blitsz = ST7789_TFTWIDTH*4*sizeof(uint16_t);
		for(i=0;i<ST7789_TFTHEIGHT;i+=4)
		{
			flash_read(SPI0, (uint8_t *)blit, blitaddr, blitsz);
			st7789_blit(0, i, ST7789_TFTWIDTH, 4, blit);
			blitaddr += blitsz;
		}
	}
#endif

	/* Test I2C */
	//i2c_init(I2C0);
	//printf("I2C0 Initialized\n\r");
	
#if 1
	/* command interp */
	cmd_init();
	printf("Command Interp Initialized\n\r");
#endif
	
	cnt = 0;
	printf("Looping...\n\r");
	clkcnt_reg = 0;
	while(1)
	{
		/* blink LED @ 200ms rate */
		if(clkcnt_reg > (24000*200))
		{
			gp_out = (gp_out&~(7<<17))|((cnt&7)<<17);
			clkcnt_reg = 0;
		}
		
#if 0
		/* master transmit test */
		if(i2c_mtx(I2C0, 0x1A, (uint8_t *)&cnt, 2))
			acia_putc('x');
		else
			acia_putc('.');
#endif

#if 0
		/* slave receive (blocking) test */
		{
			uint16_t data;
			if(i2c_srx(I2C0, 0x19, (uint8_t *)&data, 2)&1)
			{
				printf("----\n\r");
			}
			else
			{
				printf("0x%04X\n\r", data);
			}
		}
#endif
		
		cnt++;
		
#if 0
		/* simple echo */
		int c=acia_getc();
		if(c != EOF)
			acia_putc(c);
#endif
#if 1
		/* command processing */
		cmd_proc();
#endif
	}
}
