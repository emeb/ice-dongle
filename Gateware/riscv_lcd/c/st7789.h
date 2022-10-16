/*
 * st7789.h - ST7789 LCD driver for riscv_lcd
 * 10-14-22 E. Brombaugh
 * portions based on Adafruit LCD code
 */

#ifndef __st7789__
#define __st7789__

#include "riscv_lcd.h"

// Color definitions
#define	ST7789_BLACK   0x0000
#define	ST7789_BLUE    0x001F
#define	ST7789_RED     0xF800
#define	ST7789_GREEN   0x07E0
#define ST7789_CYAN    0x07FF
#define ST7789_MAGENTA 0xF81F
#define ST7789_YELLOW  0xFFE0  
#define ST7789_WHITE   0xFFFF

#define ST7789_TFTWIDTH  170
#define ST7789_TFTHEIGHT 320

void st7789_init(SPI_TypeDef *s);
void st7789_setRotation(uint8_t m);
int16_t st7789_width(void);
int16_t st7789_height(void);
void st7789_drawPixel(int16_t x, int16_t y, uint16_t color);
void st7789_drawFastVLine(int16_t x, int16_t y, int16_t h, uint16_t color);
void st7789_drawFastHLine(int16_t x, int16_t y, int16_t w, uint16_t color);
void st7789_hsv2rgb(uint8_t rgb[], uint8_t hsv[]);
uint16_t st7789_Color565(uint8_t r, uint8_t g, uint8_t b);
void st7789_emptyRect(int16_t x, int16_t y, int16_t w, int16_t h,
	uint16_t color);
void st7789_fillRect(int16_t x, int16_t y, int16_t w, int16_t h,
	uint16_t color);
void st7789_fillScreen(uint16_t color);
void st7789_drawLine(int16_t x0, int16_t y0, int16_t x1, int16_t y1,
	uint16_t color);
void st7789_drawchar(int16_t x, int16_t y, uint8_t chr, 
	uint16_t fg, uint16_t bg);
void st7789_drawstr(int16_t x, int16_t y, char *str,
	uint16_t fg, uint16_t bg);
void st7789_blit(int16_t x, int16_t y, int16_t w, int16_t h, uint16_t *src);
#endif

