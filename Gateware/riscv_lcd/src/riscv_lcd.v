// riscv_lcd.v - RISC-V soft core driving an LCD over Eye-SPI bus 
// 10-13-22 E. Brombaugh

`default_nettype none

module riscv_lcd(
	// 12MHz clock osc
	input	CLK12MHZ,
		
    // serial - GP1 is RX, GP2 is TX
    inout 	ES_GP1, ES_GP2,
	
	// SPI0 port hooked to cfg flash & psram
	inout	MEM_SPI_PICO_IO0,
			MEM_SPI_POCI_IO1,
			MEM_SPI_SCLK,
			MEM_SPI_CS,
			MEM_SPI_WP_IO2,
			MEM_SPI_HLD_IO3,
			PSRAM_CS,
			
	// SPI1 port on Eye-SPI
	inout	ES_PICO,
			ES_POCI,
			ES_SCK,
			ES_TFTCS,
	
	// I2C0 port on Eye-SPI
	inout	ES_SDA,
			ES_SCL,
	
	// GP Out for LCD
	output ES_RST, ES_DC, ES_BKL,
	
	// unused Eye-SPI selects
	output ES_SDCS, ES_MEMCS, ES_TSCS,
	
	// spares on programming header
	output SPARE10,
	input SPARE9,
	
	// LED - via drivers
	output RGB0, RGB1, RGB2
);
		
	// Fin=12, Fout=24
	wire clk, pll_lock;
	SB_PLL40_PAD #(
		.DIVR(4'b0000),
		.DIVF(7'b0111111),
		.DIVQ(3'b101),
		.FILTER_RANGE(3'b001),
		.FEEDBACK_PATH("SIMPLE"),
		.DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
		.FDA_FEEDBACK(4'b0000),
		.DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
		.FDA_RELATIVE(4'b0000),
		.SHIFTREG_DIV_MODE(2'b00),
		.PLLOUT_SELECT("GENCLK"),
		.ENABLE_ICEGATE(1'b0)
	)
	pll_inst (
		.PACKAGEPIN(CLK12MHZ),
		.PLLOUTCORE(clk),
		.PLLOUTGLOBAL(),
		.EXTFEEDBACK(),
		.DYNAMICDELAY(8'h00),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.LATCHINPUTVALUE(),
		.LOCK(pll_lock),
		.SDI(),
		.SDO(),
		.SCLK()
	);
	
	// reset generator waits > 10us afer PLL lock
	reg [7:0] reset_cnt;
	reg reset;    
	always @(posedge clk)
	begin
		if(!pll_lock)
		begin
			reset_cnt <= 8'h00;
			reset <= 1'b1;
		end
		else
		begin
			if(reset_cnt != 8'hff)
			begin
				reset_cnt <= reset_cnt + 8'h01;
				reset <= 1'b1;
			end
			else
				reset <= 1'b0;
		end
	end
	
	// system core
	wire [31:0] gpio_o;
	wire raw_rx, raw_tx;
	system uut(
		.clk24(clk),
		.reset(reset),
		
		.RX(raw_rx),
		.TX(raw_tx),
		
		.spi0_mosi(MEM_SPI_PICO_IO0),
		.spi0_miso(MEM_SPI_POCI_IO1),
		.spi0_sclk(MEM_SPI_SCLK),
		.spi0_cs0(MEM_SPI_CS),
		.spi0_cs1(PSRAM_CS),
	
		.spi1_mosi(ES_PICO),
		.spi1_miso(ES_POCI),
		.spi1_sclk(ES_SCK),
		.spi1_cs0(ES_TFTCS),
		.spi1_cs1(ES_SDCS),
	
		.i2c0_sda(ES_SDA),
		.i2c0_scl(ES_SCL),
	
		.gp_out(gpio_o)
	);
	
	// remaining memory bus signals tied inactive
	assign MEM_SPI_WP_IO2 = 1'b1;
	assign MEM_SPI_HLD_IO3 = 1'b1;
	//assign PSRAM_CS = 1'b1;
	
	// Serial I/O w/ pullup on RX
	SB_IO #(
		.PIN_TYPE(6'b101001),
		.PULLUP(1'b1),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) urx_io (
		.PACKAGE_PIN(SPARE9),
		.LATCH_INPUT_VALUE(1'b0),
		.CLOCK_ENABLE(1'b0),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(1'b0),
		.OUTPUT_ENABLE(1'b0),
		.D_OUT_0(1'b0),
		.D_OUT_1(1'b0),
		.D_IN_0(raw_rx),
		.D_IN_1()
	);
	SB_IO #(
		.PIN_TYPE(6'b101001),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) utx_io (
		.PACKAGE_PIN(SPARE10),
		.LATCH_INPUT_VALUE(1'b0),
		.CLOCK_ENABLE(1'b0),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(1'b0),
		.OUTPUT_ENABLE(1'b1),
		.D_OUT_0(raw_tx),
		.D_OUT_1(1'b0),
		.D_IN_0(),
		.D_IN_1()
	);
	
	// LED dimming PWM
	reg [3:0] pwmcnt;
	reg pwm;
	always @(posedge clk)
	begin
		if(reset)
		begin
			pwmcnt <= 4'h0;
			pwm <= 1'b0;
		end
		else
		begin
			pwmcnt <= pwmcnt + 4'h1;
			pwm <= pwmcnt > 0 ? 1'b0 : 1'b1;
		end
	end
	
	// RGB LED Driver IP core
	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000011")
	) RGBA_DRIVER (
		.CURREN(1'b1),
		.RGBLEDEN(pwm),
		.RGB0PWM(gpio_o[17]),
		.RGB1PWM(gpio_o[18]),
		.RGB2PWM(gpio_o[19]),
		.RGB0(RGB0),
		.RGB1(RGB1),
		.RGB2(RGB2)
	);
	
	// LCD control lines
	assign ES_RST = gpio_o[31];
	assign ES_DC = gpio_o[30];
	assign ES_BKL = gpio_o[29];
	
	// Unused Eye-SPI selects
	//assign ES_SDCS = 1'b1;
	assign ES_MEMCS = 1'b1;
	assign ES_TSCS = 1'b1;
endmodule
