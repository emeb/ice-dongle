// ice-dongle blinky for initial test
// 10-13-22 E. Brombaugh

module blinky(
	// RGB output
    output RGB0, RGB1, RGB2
);
	//------------------------------
	// Instantiate LF Osc
	//------------------------------
	wire CLKLF;
	SB_LFOSC OSCInst1 (
		.CLKLFEN(1'b1),
		.CLKLFPU(1'b1),
		.CLKLF(CLKLF)
	);
	
	//------------------------------
	// Divide the clock
	//------------------------------
	reg [13:0] clkdiv;
	reg onepps;
	always @(posedge CLKLF)
	begin		
		if(clkdiv == 14'd0)
		begin
			onepps <= 1'b1;
			clkdiv <= 14'd9999;
		end
		else
		begin
			onepps <= 1'b0;
			clkdiv <= clkdiv - 14'd1;
		end
	end
	
	//------------------------------
	// LED signals
	//------------------------------
	reg [2:0] state;
	always @(posedge CLKLF)
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
