// tb_system.v - testbench for riscv system
// 06-30-19 E. Brombaugh

`timescale 1ns/1ps
`default_nettype none

module tb_system;
    reg clk24;
    reg reset;
	reg RX;
    wire TX;
	wire spi0_mosi, spi0_miso, spi0_sclk, spi0_cs0, spi0_cs1;
	wire spi1_mosi, spi1_miso, spi1_sclk, spi1_cs0, spi1_cs1;
	wire i2c0_sda, i2c0_scl;
	wire [31:0] gp_out;
	
    // 24MHz clock source
    always
        #21 clk24 = ~clk24;
    
    // reset
    initial
    begin
`ifdef icarus
  		$dumpfile("tb_system.vcd");
		$dumpvars;
`endif
        
        // init regs
        clk24 = 1'b0;
        reset = 1'b1;
        RX = 1'b1;
        
        // release reset
        #100
        reset = 1'b0;
        
`ifdef icarus
        // stop after 1 sec
		#2000000 $finish;
`endif
    end
    
    // Unit under test
    system uut(
        .clk24(clk24),     // 24MHz system clock
        .reset(reset),     // high-true reset
	
        .RX(RX),           // serial input
        .TX(TX),           // serial output
	
		.spi0_mosi(spi0_mosi),	// SPI core 0
		.spi0_miso(spi0_miso),
		.spi0_sclk(spi0_sclk),
		.spi0_cs0(spi0_cs0),
		.spi0_cs1(spi0_cs1),
	
		.spi1_mosi(spi1_mosi),	// SPI core 1
		.spi1_miso(spi1_miso),
		.spi1_sclk(spi1_sclk),
		.spi1_cs0(spi1_cs0),
		.spi1_cs1(spi1_cs1),
	
		.i2c0_sda(i2c0_sda),	// I2C core 0
		.i2c0_scl(i2c0_scl),
	
		.gp_out(gp_out)    // general purpose output
    );
endmodule
