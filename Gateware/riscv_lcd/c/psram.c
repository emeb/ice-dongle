/*
 * psram.c - SPI PSRAM driver
 * 10-15-22 E. Brombaugh
 */

#include "psram.h"
#include "spi.h"

/* psram cs bit */
#define PSRAM_CSBIT 1

/* psram commands */
#define PSRAM_WRIT 0x02 // write data
#define PSRAM_READ 0x03 // read data
#define PSRAM_ERST 0x66 // enable reset
#define PSRAM_RST  0x99 // reset
#define PSRAM_ID   0x9f // get ID bytes

/*
 * send a header to the SPI PSRAM (for read/write commands)
 */
void psram_header(SPI_TypeDef *s, uint8_t cmd, uint32_t addr)
{
	uint8_t txdat[4];
	
	/* assemble header */
	txdat[0] = cmd;
	txdat[1] = (addr>>16)&0xff;
	txdat[2] = (addr>>8)&0xff;
	txdat[3] = (addr)&0xff;
	
	/* send the header */
	spi_transmit(s, txdat, 4);
}

/*
 * read bytes from SPI PSRAM
 */
void psram_read(SPI_TypeDef *s, uint8_t *dst, uint32_t addr, uint32_t len)
{
	uint8_t dummy __attribute ((unused));
	
	spi_cs_low(s, PSRAM_CSBIT);
	
	/* send read header */
	psram_header(s, PSRAM_READ, addr);
	
	/* wait for tx ready */
	spi_tx_wait(s);
	
	/* dummy reads */
	dummy = s->SPIRXDR;
	dummy = s->SPIRXDR;
	
	/* get the buffer */
	spi_receive(s, dst, len);
	
	spi_cs_high(s);
}

/*
 * write bytes to SPI PSRAM
 */
void psram_write(SPI_TypeDef *s, uint8_t *src, uint32_t addr, uint32_t len)
{
	spi_cs_low(s, PSRAM_CSBIT);
	
	/* send read header */
	psram_header(s, PSRAM_WRIT, addr);
	
	/* send data packet */
	spi_transmit(s, src, len);
	
	spi_cs_high(s);
}

/*
 * get ID from SPI PSRAM
 */
uint32_t psram_id(SPI_TypeDef *s)
{
	uint8_t result[4];
	
	spi_cs_low(s, PSRAM_CSBIT);
	
	/* send command */
	psram_header(s, PSRAM_ID, 0);
	
	result[0] = s->SPIRXDR;	// dummy read
	result[0] = s->SPIRXDR;	// dummy read
	
	/* get id bytes */
	spi_receive(s, result, 4);

	spi_cs_high(s);
	
	return (result[0]<<24) | (result[1]<<16) | (result[2]<<8) | result[3];
}
