// icestick_6502_top.v - top level for tst_6502 on an icestick
// 03-02-19 E. Brombaugh

`default_nettype none

module top(
	// 12MHz clock osc
	input	CLK12MHZ,

	// spares on programming header are serial I/O
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
    
	// test unit
	wire [7:0] gpio_o, gpio_i;
	assign gpio_i = 8'h00;
	wire raw_rx, raw_tx;
	tst_6502 uut(
		.clk(clk),
		.reset(reset),
		
		.gpio_o(gpio_o),
		.gpio_i(gpio_i),
		
		.RX(raw_rx),
		.TX(raw_tx)
	);
    
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
		.RGB0PWM(gpio_o[7]),
		.RGB1PWM(gpio_o[6]),
		.RGB2PWM(gpio_o[5]),
		.RGB0(RGB0),
		.RGB1(RGB1),
		.RGB2(RGB2)
	);
endmodule
