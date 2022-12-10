`default_nettype none

`define WITH_BUTTON
`define HFOSC

module top (
	// USB
	inout  wire usb_dp,
	inout  wire usb_dn,
	output wire usb_pu,

`ifdef WITH_BUTTON
	// Button
	input  wire btn,
`endif

	// Clock
	input  wire clk_in,
	
	// SPI port 0
	inout	wire spi0_mosi,
			spi0_miso,
			spi0_sclk,
			spi0_cs0,
			spi0_wp,
			spi0_hld,
			spi0_cs1,
	
	// LED - via drivers
	output RGB0, RGB1, RGB2
);

	// Which image to reboot to
	// 01 for no2bootloader, 00 for foboot/tinyfpga-bootloader
	localparam [1:0] BOOT_IMAGE = 2'b01;


	// Signals
	// -------

	// Pipe data ( USB side )
	wire [7:0] in_usb_data;
	wire       in_usb_last;
	wire       in_usb_valid;
	wire       in_usb_ready;
	wire       in_usb_flush_now;
	wire       in_usb_flush_time;

	wire [7:0] out_usb_data;
	wire       out_usb_last;
	wire       out_usb_valid;
	wire       out_usb_ready;

	// Pipe data ( System side )
	wire [7:0] in_usr_data;
	wire       in_usr_last;
	wire       in_usr_valid;
	wire       in_usr_ready;

	wire [7:0] out_usr_data;
	wire       out_usr_last;
	wire       out_usr_valid;
	wire       out_usr_ready;

	// Bootloader request
	wire       bootloader;

	// Clock / Reset
	wire rst_in;

	wire clk_usb;
	wire rst_usb;

	wire clk_usr;
	wire rst_usr;

	wire [7:0] gpio_o;

	// uACM
	// ----

	// Core
	muacm acm_I (
		.usb_dp        (usb_dp),
		.usb_dn        (usb_dn),
		.usb_pu        (usb_pu),
		.in_data       (in_usb_data),
		.in_last       (in_usb_last),
		.in_valid      (in_usb_valid),
		.in_ready      (in_usb_ready),
		.in_flush_now  (in_usb_flush_now),
		.in_flush_time (in_usb_flush_time),
		.out_data      (out_usb_data),
		.out_last      (out_usb_last),
		.out_valid     (out_usb_valid ),
		.out_ready     (out_usb_ready ),
		.bootloader    (bootloader),
		.clk           (clk_usb),
		.rst           (rst_usb)
	);

	// Cross clock to 'user' domain
	muacm_xclk xclk_usr2usb_I (
		.i_data (in_usr_data),
		.i_last (in_usr_last),
		.i_valid(in_usr_valid),
		.i_ready(in_usr_ready),
		.i_clk  (clk_usr),
		.o_data (in_usb_data),
		.o_last (in_usb_last),
		.o_valid(in_usb_valid),
		.o_ready(in_usb_ready),
		.o_clk  (clk_usb),
		.rst    (rst_usb)
	);

	muacm_xclk xclk_usb2usr_I (
		.i_data (out_usb_data),
		.i_last (out_usb_last),
		.i_valid(out_usb_valid),
		.i_ready(out_usb_ready),
		.i_clk  (clk_usb),
		.o_data (out_usr_data),
		.o_last (out_usr_last),
		.o_valid(out_usr_valid),
		.o_ready(out_usr_ready),
		.o_clk  (clk_usr),
		.rst    (rst_usb)
	);


	// "User" application
	// ------------------

	// Static options:
	//   - Don't immediate flush
	//   - Flush after timeout expires
	assign in_usb_flush_now = 1'b0;
	assign in_usb_flush_time = 1'b1;
	assign in_usr_last   = 1'b0;
	
//`define loopback
`ifdef loopback
	// Simple loopback
	assign in_usr_data   = out_usr_data;
	assign in_usr_valid  = out_usr_valid;
	assign out_usr_ready = in_usr_ready;
`else
	// soft CPU system
	cpu_system system_I (
		.clk	(clk_usr),
		.rst	(rst_usr),
		.rx_data(out_usr_data),
		.rx_rdy (out_usr_ready),
		.rx_val (out_usr_valid),
		.tx_data(in_usr_data),
		.tx_rdy (in_usr_ready),
		.tx_val (in_usr_valid),
		.spi0_mosi(spi0_mosi),
		.spi0_miso(spi0_miso),
		.spi0_sclk(spi0_sclk),
		.spi0_cs0(spi0_cs0),
		.gpio_i (8'h00),
		.gpio_o (gpio_o)
	);
	assign spi0_wp = 1'b1;
	assign spi0_hld = 1'b1;
	assign spi0_cs1 = 1'b1;
`endif


	// DFU helper
	// ----------

`ifdef WITH_BUTTON
	dfu_helper #(
		.BTN_MODE(3),
		.BOOT_IMAGE(BOOT_IMAGE)
	) dfu_helper_I (
		.boot_sel (BOOT_IMAGE),
		.boot_now (bootloader),
		.btn_in   (btn),
		.btn_tick (),
		.btn_val  (),
		.btn_press(rst_in),
		.clk      (clk_usb),
		.rst      (rst_usb)
	);
`else
	assign rst_in = 1'b0;

	reg boot = 1'b0;
	always @(posedge clk_usb)
		boot <= boot | bootloader;

	SB_WARMBOOT warmboot (
		.BOOT (boot),
		.S0   (BOOT_IMAGE[0]),
		.S1   (BOOT_IMAGE[1])
	);
`endif


	// Clock / Reset
	// -------------

`ifdef HFOSC

	// Use HF OSC to generate USB clock
	sysmgr_hfosc sysmgr_I (
		.rst_in (rst_in),
		.clk_out(clk_usb),
		.rst_out(rst_usb)
	);

	// Use the clock input "as-is" for user clock
	assign clk_usr = clk_in;

	// Generate a reset signal with synchronized release in clk_usr
	reg rst_usr_r;

	always @(posedge clk_usr or posedge rst_usb)
		if (rst_usb)
			rst_usr_r <= 1'b1;
		else
			rst_usr_r <= 1'b0;

	SB_GB rst_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER(rst_usr_r),
		.GLOBAL_BUFFER_OUTPUT(rst_usr)
	);

`else

	// Generate both 48 MHz (for USB) and 24 MHz (for "user") out of the PLL
	sysmgr_pll sysmgr_I (
		.clk_in (clk_in),
		.rst_in (rst_in),
		.clk_48m(clk_usb),
		.clk_24m(clk_usr),
		.rst_out(rst_usb)
	);

	// They're both from PLL and sync "enough" to use the same signal
	assign rst_usr = rst_usb;

`endif

	// LED dimming PWM
	reg [3:0] pwmcnt;
	reg pwm;
	always @(posedge clk_usr)
	begin
		if(rst_usr)
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

endmodule // top
