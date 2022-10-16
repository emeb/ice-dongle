/*
 * st7789.c - ST7789 LCD driver for riscv_lcd
 * 10-14-22 E. Brombaugh
 * portions based on Adafruit LCD code
 */

#include "st7789.h"
#include "spi.h"
#include "clkcnt.h"
#include "font_8x8.h"

#define ST7789_BKL_LOW()   (gp_out&=~(1<<29))
#define ST7789_BKL_HIGH()  (gp_out|=(1<<29))
#define ST7789_DC_CMD()    (gp_out&=~(1<<30))
#define ST7789_DC_DATA()   (gp_out|=(1<<30))
#define ST7789_RST_LOW()   (gp_out&=~(1<<31))
#define ST7789_RST_HIGH()  (gp_out|=(1<<31))

#define ST7789_CSBIT 0

#define ST_CMD            0x100
#define ST_CMD_DELAY      0x200
#define ST_CMD_END        0x400

#define ST77XX_NOP        0x00
#define ST77XX_SWRESET    0x01
#define ST77XX_RDDID      0x04
#define ST77XX_RDDST      0x09

#define ST77XX_SLPIN      0x10
#define ST77XX_SLPOUT     0x11
#define ST77XX_PTLON      0x12
#define ST77XX_NORON      0x13

#define ST77XX_INVOFF     0x20
#define ST77XX_INVON      0x21
#define ST77XX_DISPOFF    0x28
#define ST77XX_DISPON     0x29
#define ST77XX_CASET      0x2A
#define ST77XX_RASET      0x2B
#define ST77XX_RAMWR      0x2C
#define ST77XX_RAMRD      0x2E

#define ST77XX_PTLAR      0x30
#define ST77XX_COLMOD     0x3A
#define ST77XX_MADCTL     0x36

#define ST77XX_MADCTL_MY  0x80
#define ST77XX_MADCTL_MX  0x40
#define ST77XX_MADCTL_MV  0x20
#define ST77XX_MADCTL_ML  0x10
#define ST77XX_MADCTL_RGB 0x08
#define ST77XX_MADCTL_MH  0x04


#define ST77XX_RDID1      0xDA
#define ST77XX_RDID2      0xDB
#define ST77XX_RDID3      0xDC
#define ST77XX_RDID4      0xDD

/* these values look better - more saturated, less flicker */
const static uint16_t initlst[] = {
    ST77XX_SWRESET | ST_CMD,        //  1: Software reset, no args, w/delay
    ST_CMD_DELAY | 150,             //  150 ms delay
    ST77XX_SLPOUT | ST_CMD ,        //  2: Out of sleep mode, no args, w/delay
	ST_CMD_DELAY | 500,             //  500 ms delay
    ST77XX_COLMOD | ST_CMD ,        //  3: Set color mode
      0x55,                         //     16-bit color
	ST_CMD_DELAY | 10,              //     10 ms delay
    ST77XX_MADCTL | ST_CMD ,        //  4: Mem access ctrl (directions), 1 arg:
      0x00,                         //     Row/col addr, bottom-top refresh
    ST77XX_CASET | ST_CMD  ,        //  5: Column addr set, 4 args, no delay:
      0x00,
      0,                            //     XSTART = 0
      0,
      240,                          //     XEND = 240
    ST77XX_RASET | ST_CMD  ,        //  6: Row addr set, 4 args, no delay:
      0x00,
      0,                            //     YSTART = 0
      320>>8,
      320&0xff,                     //     YEND = 320
    ST77XX_INVON | ST_CMD  ,        //  7: hack
    ST_CMD_DELAY | 10,              //  10 ms
    ST77XX_NORON | ST_CMD  ,        //  8: Normal display on, no args, w/delay
    ST_CMD_DELAY | 10,              //  10 ms delay
    ST77XX_DISPON | ST_CMD ,        //  9: Main screen turn on, no args, delay
    ST_CMD_DELAY | 500,             //  500 ms delay
	ST_CMD_END                      //  END OF LIST
};

/* pointer to SPI port */
SPI_TypeDef *st7789_spi;

/* LCD state */
uint8_t rotation;
int16_t _width, _height, rowstart, colstart;

/*
 * send single byte via SPI - cmd or data depends on bit 8
 */
void st7789_write(uint16_t dat)
{
	if((dat&ST_CMD) == ST_CMD)
		ST7789_DC_CMD();
	else
		ST7789_DC_DATA();

	spi_tx_byte(st7789_spi, dat&0xff, ST7789_CSBIT);
}

/*
 * initialize the LCD
 */
void st7789_init(SPI_TypeDef *s)
{
	ST7789_BKL_LOW();
	
	// save SPI port
	st7789_spi = s;
	
	// Reset it
	ST7789_RST_LOW();
	clkcnt_delayms(50);
	ST7789_RST_HIGH();
	clkcnt_delayms(50);

	// Send init command list
	uint16_t *addr = (uint16_t *)initlst, ms;
	while(*addr != ST_CMD_END)
	{
		if((*addr & ST_CMD_DELAY) != ST_CMD_DELAY)
			st7789_write(*addr++);
		else
		{
			ms = (*addr++)&0x1ff;        // strip delay time (ms)
			clkcnt_delayms(ms);
		}	
	}
	
	// rotation
	st7789_setRotation(2);
	
	// clear to black
	st7789_fillScreen(ST7789_BLACK);

	ST7789_BKL_HIGH();
}

// set orientation of display
void st7789_setRotation(uint8_t m)
{
	st7789_write(ST77XX_MADCTL | ST_CMD);
	rotation = m % 4; // can't be higher than 3
	switch (rotation)
	{
		case 0:
			st7789_write(ST77XX_MADCTL_MX | ST77XX_MADCTL_MY );
			_width  = ST7789_TFTWIDTH;
			_height = ST7789_TFTHEIGHT;
			rowstart = 0;
			colstart = 35;
			break;

		case 1:
			st7789_write(ST77XX_MADCTL_MY | ST77XX_MADCTL_MV );
			_width  = ST7789_TFTHEIGHT;
			_height = ST7789_TFTWIDTH;
			rowstart = 35;
			colstart = 0;
			break;

		case 2:
			st7789_write(0);
			_width  = ST7789_TFTWIDTH;
			_height = ST7789_TFTHEIGHT;
			rowstart = 0;
			colstart = 35;
			break;

		case 3:
			st7789_write(ST77XX_MADCTL_MX | ST77XX_MADCTL_MV );
			_width  = ST7789_TFTHEIGHT;
			_height = ST7789_TFTWIDTH;
			rowstart = 35;
			colstart = 0;
			break;
	}
}

/*
 * get dimensions
 */
int16_t st7789_width(void)
{
	return _width;
}

int16_t st7789_height(void)
{
	return _height;
}

/*
 * opens a window into display mem for bitblt
 */
void st7789_setAddrWindow(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1)
{
	st7789_write(ST77XX_CASET | ST_CMD); // Column addr set
	x0 += colstart;
	st7789_write(x0>>8);
	st7789_write(x0&0xff);     // XSTART
	x1 += colstart;
	st7789_write(x1>>8);
	st7789_write(x1&0xff);     // XEND

	st7789_write(ST77XX_RASET | ST_CMD); // Row addr set
	y0 += rowstart;
	st7789_write(y0>>8);
	st7789_write(y0&0xff);     // YSTART
	y1 += rowstart;
	st7789_write(y1>>8);
	st7789_write(y1&0xff);     // YEND

	st7789_write(ST77XX_RAMWR | ST_CMD); // write to RAM
}

/*
 * Convert HSV triple to RGB triple
 * use algorithm from
 * http://en.wikipedia.org/wiki/HSL_and_HSV#Converting_to_RGB
 */
void st7789_hsv2rgb(uint8_t rgb[], uint8_t hsv[])
{
	uint16_t C;
	int16_t Hprime, Cscl;
	uint8_t hs, X, m;
	
	/* default */
	rgb[0] = 0;
	rgb[1] = 0;
	rgb[2] = 0;
	
	/* calcs are easy if v = 0 */
	if(hsv[2] == 0)
		return;
	
	/* C is the chroma component */
	C = ((uint16_t)hsv[1] * (uint16_t)hsv[2])>>8;
	
	/* Hprime is fixed point with range 0-5.99 representing hue sector */
	Hprime = (int16_t)hsv[0] * 6;
	
	/* get intermediate value X */
	Cscl = (Hprime%512)-256;
	Cscl = Cscl < 0 ? -Cscl : Cscl;
	Cscl = 256 - Cscl;
	X = ((uint16_t)C * Cscl)>>8;
	
	/* m is value offset */
	m = hsv[2] - C;
	
	/* get the hue sector (1 of 6) */
	hs = (Hprime)>>8;
	
	/* map by sector */
	switch(hs)
	{
		case 0:
			/* Red -> Yellow sector */
			rgb[0] = C + m;
			rgb[1] = X + m;
			rgb[2] = m;
			break;
		
		case 1:
			/* Yellow -> Green sector */
			rgb[0] = X + m;
			rgb[1] = C + m;
			rgb[2] = m;
			break;
		
		case 2:
			/* Green -> Cyan sector */
			rgb[0] = m;
			rgb[1] = C + m;
			rgb[2] = X + m;
			break;
		
		case 3:
			/* Cyan -> Blue sector */
			rgb[0] = m;
			rgb[1] = X + m;
			rgb[2] = C + m;
			break;
		
		case 4:
			/* Blue -> Magenta sector */
			rgb[0] = X + m;
			rgb[1] = m;
			rgb[2] = C + m;
			break;
		
		case 5:
			/* Magenta -> Red sector */
			rgb[0] = C + m;
			rgb[1] = m;
			rgb[2] = X + m;
			break;
	}
}

/*
 * Convert 8-bit (each) R,G,B to 16-bit rgb565 packed color
 */
uint16_t st7789_Color565(uint8_t r, uint8_t g, uint8_t b)
{
	return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
}

/*
 * fast color fill
 */
void st7789_fillcolor(uint16_t color, uint32_t sz)
{
	uint8_t lo = color&0xff, hi = color>>8;
	
	while(sz--)
	{
		/* wait for tx ready */
		spi_tx_wait(st7789_spi);
	
		/* transmit hi byte */
		st7789_spi->SPITXDR = hi;
		
		/* wait for tx ready */
		spi_tx_wait(st7789_spi);
	
		/* transmit hi byte */
		st7789_spi->SPITXDR = lo;
	}
}

/*
 * draw single pixel
 */
void st7789_drawPixel(int16_t x, int16_t y, uint16_t color)
{

	if((x < 0) ||(x >= _width) || (y < 0) || (y >= _height)) return;

	st7789_setAddrWindow(x,y,x+1,y+1);

	ST7789_DC_DATA();
	spi_cs_low(st7789_spi, ST7789_CSBIT);
    st7789_fillcolor(color, 1);
	spi_cs_high(st7789_spi);
}

/*
 * abs() helper function for line drawing
 */
int16_t st7789_abs(int16_t x)
{
	return (x<0) ? -x : x;
}

/*
 * swap() helper function for line drawing
 */
void st7789_swap(int16_t *z0, int16_t *z1)
{
	int16_t temp = *z0;
	*z0 = *z1;
	*z1 = temp;
}

/*
 * Bresenham line draw routine swiped from Wikipedia
 */
void st7789_drawLine(int16_t x0, int16_t y0, int16_t x1, int16_t y1,
	uint16_t color)
{
	int8_t steep;
	int16_t deltax, deltay, error, ystep, x, y;
	
	/* flip sense 45deg to keep error calc in range */
	steep = (st7789_abs(y1 - y0) > st7789_abs(x1 - x0));
	
	if(steep)
	{
		st7789_swap(&x0, &y0);
		st7789_swap(&x1, &y1);
	}
	
	/* run low->high */
	if(x0 > x1)
	{
		st7789_swap(&x0, &x1);
		st7789_swap(&y0, &y1);
	}
	
	/* set up loop initial conditions */
	deltax = x1 - x0;
	deltay = st7789_abs(y1 - y0);
	error = deltax/2;
	y = y0;
	if(y0 < y1)
		ystep = 1;
	else
		ystep = -1;
    	
	/* loop x */
	for(x=x0;x<=x1;x++)
	{
		/* plot point */
		if(steep)
			/* flip point & plot */
			st7789_drawPixel(y, x, color);
		else
			/* just plot */
			st7789_drawPixel(x, y, color);
		
		/* update error */
		error = error - deltay;
		
		/* update y */
		if(error < 0)
		{
			y = y + ystep;
			error = error + deltax;
		}
	}
}

/*
 * fast vert line
 */
void st7789_drawFastVLine(int16_t x, int16_t y, int16_t h, uint16_t color)
{
	// clipping
	if((x >= _width) || (y >= _height)) return;
	if((y+h-1) >= _height) h = _height-y;
	st7789_setAddrWindow(x, y, x, y+h-1);

	ST7789_DC_DATA();
	spi_cs_low(st7789_spi, ST7789_CSBIT);
	st7789_fillcolor(color, h);
	spi_cs_high(st7789_spi);
}

/*
 * fast horiz line
 */
void st7789_drawFastHLine(int16_t x, int16_t y, int16_t w, uint16_t color)
{
	// clipping
	if((x >= _width) || (y >= _height)) return;
	if((x+w-1) >= _width)  w = _width-x;
	st7789_setAddrWindow(x, y, x+w-1, y);

	ST7789_DC_DATA();
	spi_cs_low(st7789_spi, ST7789_CSBIT);
	st7789_fillcolor(color, w);
	spi_cs_high(st7789_spi);
}

/*
 * empty rect
 */
void st7789_emptyRect(int16_t x, int16_t y, int16_t w, int16_t h, uint16_t color)
{
	/* top & bottom */
    st7789_drawFastHLine(x, y, w, color);
    st7789_drawFastHLine(x, y+h-1, w, color);
    
	/* left & right - don't redraw corners */
    st7789_drawFastVLine(x, y+1, h-2, color);
    st7789_drawFastVLine(x+w-1, y+1, h-2, color);
}

/*
 * fill a rectangle
 */
void st7789_fillRect(int16_t x, int16_t y, int16_t w, int16_t h,
	uint16_t color)
{
	// clipping
	if((x >= _width) || (y >= _height)) return;
	if((x + w - 1) >= _width)  w = _width  - x;
	if((y + h - 1) >= _height) h = _height - y;

	st7789_setAddrWindow(x, y, x+w-1, y+h-1);

	ST7789_DC_DATA();
	spi_cs_low(st7789_spi, ST7789_CSBIT);
	st7789_fillcolor(color, h*w);
	spi_cs_high(st7789_spi);
}

/*
 * fill screen w/ single color
 */
void st7789_fillScreen(uint16_t color)
{
	st7789_fillRect(0, 0, _width, _height, color);
}

/*
 * Draw character direct to the display
 */
void st7789_drawchar(int16_t x, int16_t y, uint8_t chr, 
	uint16_t fg, uint16_t bg)
{
	uint16_t i, j, col;
	uint8_t d;
	
	st7789_setAddrWindow(x, y, x+7, y+7);
	
	ST7789_DC_DATA();
	spi_cs_low(st7789_spi, ST7789_CSBIT);
	for(i=0;i<8;i++)
	{
		d = fontdata[(chr<<3)+i];
		for(j=0;j<8;j++)
		{
			if(d&0x80)
				col = fg;
			else
				col = bg;
			
			st7789_fillcolor(col, 1);
			
			// next bit
			d <<= 1;
		}
	}
	spi_cs_high(st7789_spi);
}

// draw a string to the display
void st7789_drawstr(int16_t x, int16_t y, char *str,
	uint16_t fg, uint16_t bg)
{
	uint8_t c;
	
	while((c=*str++))
	{
		st7789_drawchar(x, y, c, fg, bg);
		x += 8;
		if(x>_width)
			break;
	}
}

/*
 * send a buffer to the LCD
 */
void st7789_blit(int16_t x, int16_t y, int16_t w, int16_t h, uint16_t *src)
{
	// clipping
	if((x >= _width) || (y >= _height)) return;
	if((x + w - 1) >= _width)  w = _width  - x;
	if((y + h - 1) >= _height) h = _height - y;

	st7789_setAddrWindow(x, y, x+w-1, y+h-1);

	ST7789_DC_DATA();
	spi_cs_low(st7789_spi, ST7789_CSBIT);
	spi_transmit(st7789_spi, (uint8_t *)src, h*w*sizeof(uint16_t));
	spi_cs_high(st7789_spi);
}

