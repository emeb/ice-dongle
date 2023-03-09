// rgb_driver.v - ice40 RGB driver IP cores for 6502
// 03-08-2023 E. Brombaugh

module rgb_driver(
		input wire clk,			// system clock
		input wire rst,			// system reset
		input wire cs,			// chip select
		input wire we,			// write enable
		input wire [4:0] addr,	// 5-bit address
		input wire [8:0] din,	// 8-bit data bus input
		output wire [2:0]rgb_pad	// RGB pad drive
);
	// overall control register
	reg [2:0] ctrl;
	always @(posedge clk)
		if(rst)
			ctrl <= 3'b000;
		else if(~addr[4] & cs & we)
			ctrl <= din[2:0];
			
	// pwm driver
	wire [2:0] pwm;
	SB_LEDDA_IP led_I (
		.LEDDCS   (addr[4] & cs),
		.LEDDCLK  (clk),
		.LEDDDAT7 (din[7]),
		.LEDDDAT6 (din[6]),
		.LEDDDAT5 (din[5]),
		.LEDDDAT4 (din[4]),
		.LEDDDAT3 (din[3]),
		.LEDDDAT2 (din[2]),
		.LEDDDAT1 (din[1]),
		.LEDDDAT0 (din[0]),
		.LEDDADDR3(addr[3]),
		.LEDDADDR2(addr[2]),
		.LEDDADDR1(addr[1]),
		.LEDDADDR0(addr[0]),
		.LEDDDEN  (we),
		.LEDDEXE  (ctrl[0]),
		.PWMOUT0  (pwm[0]),
		.PWMOUT1  (pwm[1]),
		.PWMOUT2  (pwm[2]),
		.LEDDON   ()
	);

	// pad driver
	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) rgb_drv_I (
		.RGBLEDEN(ctrl[1]),
		.RGB0PWM (pwm[0]),
		.RGB1PWM (pwm[1]),
		.RGB2PWM (pwm[2]),
		.CURREN  (ctrl[2]),
		.RGB0    (rgb_pad[0]),
		.RGB1    (rgb_pad[1]),
		.RGB2    (rgb_pad[2])
	);

endmodule
