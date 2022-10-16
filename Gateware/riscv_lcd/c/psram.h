/*
 * psram.h - SPI PSRAM driver
 * 10-15-22 E. Brombaugh
 */

#ifndef __psram__
#define __psram__

#include "riscv_lcd.h"

void psram_read(SPI_TypeDef *s, uint8_t *dst, uint32_t addr, uint32_t len);
void psram_write(SPI_TypeDef *s, uint8_t *src, uint32_t addr, uint32_t len);
uint32_t psram_id(SPI_TypeDef *s);

#endif

