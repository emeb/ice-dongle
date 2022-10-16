// ice-dongle oscillator test
// 10-13-22 E. Brombaugh

module osc_tst(
	// 12MHz Clock input
	input CLK12MHZ,
	
	// RGB output
    output RGB0, RGB1, RGB2
);
`define USE_PLL
`ifdef USE_PLL
	//------------------------------
	// Clock PLL
	//------------------------------
	// Fin=12, FoutA=24, FoutB=48
	wire clk, clk24, pll_lock;
	SB_PLL40_2F_PAD #(
		.DIVR(4'b0000),
		.DIVF(7'b0111111),	// 24/48
		.DIVQ(3'b100),
		.FILTER_RANGE(3'b001),
		.FEEDBACK_PATH("SIMPLE"),
		.DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
		.FDA_FEEDBACK(4'b0000),
		.DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
		.FDA_RELATIVE(4'b0000),
		.SHIFTREG_DIV_MODE(2'b00),
		.PLLOUT_SELECT_PORTA("GENCLK_HALF"),
		.PLLOUT_SELECT_PORTB("GENCLK"),
		.ENABLE_ICEGATE_PORTA(1'b0),
		.ENABLE_ICEGATE_PORTB(1'b0)
	)
	pll_inst (
		.PACKAGEPIN(CLK12MHZ),
		.PLLOUTCOREA(),
		.PLLOUTGLOBALA(clk24),
		.PLLOUTCOREB(),
		.PLLOUTGLOBALB(clk),
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
`else
	wire clk = CLK12MHZ;
	wire clk24 = 1'b0;
	wire pll_lock = 1'b1;
`endif

	//------------------------------
	// reset generator waits > 10us
	//------------------------------
	reg [9:0] reset_cnt;
	reg reset, reset24;    
	always @(posedge clk or negedge pll_lock)
	begin
		if(!pll_lock)
		begin
			reset_cnt <= 10'h000;
			reset <= 1'b1;
		end
		else
		begin
			if(reset_cnt != 10'h3ff)
			begin
				reset_cnt <= reset_cnt + 10'h001;
				reset <= 1'b1;
			end
			else
				reset <= 1'b0;
		end
	end
	
	always @(posedge clk24 or negedge pll_lock)
		if(!pll_lock)
			reset24 <= 1'b1;
		else
			reset24 <= reset;
	
	//------------------------------
	// Divide the clock down to 1 second
	//------------------------------
	reg [26:0] clkdiv;
	reg onepps;
	always @(posedge clk)
	begin		
		if(clkdiv == 27'd0)
		begin
			onepps <= 1'b1;
			clkdiv <= 27'd48000000;
		end
		else
		begin
			onepps <= 1'b0;
			clkdiv <= clkdiv - 27'd1;
		end
	end
	
	//------------------------------
	// LED signals
	//------------------------------
	reg [2:0] state;
	always @(posedge clk)
	begin
		if(onepps)
			state <= state + 3'd1;
	end
	
	//------------------------------
	// Instantiate RGB DRV 
	//------------------------------
	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) RGBA_DRIVER (
		.CURREN(1'b1),
		.RGBLEDEN(1'b1),
		.RGB0PWM(state[0]),
		.RGB1PWM(state[1]),
		.RGB2PWM(state[2]),
		.RGB0(RGB0),
		.RGB1(RGB1),
		.RGB2(RGB2)
	);
endmodule
