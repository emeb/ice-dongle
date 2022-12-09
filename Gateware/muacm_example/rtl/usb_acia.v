// usb_acia.v - ACIA mimic of interface to MUACM
// 12-07-22 E. Brombaugh

`default_nettype none

module usb_acia(
	input clk,				// system clock
	input rst,				// system reset
	input cs,				// chip select
	input we,				// write enable
	input rs,				// register select
	input [7:0] din,		// data bus input
	output reg [7:0] dout,	// data bus output
	input wire [7:0] rx_data,	// data received from USB
	output reg rx_rdy,			// ready for rx data (data accepted)
	input wire rx_val,			// data valid (data available)
	output reg [7:0] tx_data,	// data sent to USB
	input wire tx_rdy,			// ready for tx data
	output reg tx_val,			// tx data available
	output irq				// high-true interrupt request
);	
	// generate tx_start signal on write to register 1
	wire tx_start = cs & rs & we;
	
	// load control register
	reg [1:0] counter_divide_select, tx_start_control;
	reg [2:0] word_select; // dummy
	reg receive_interrupt_enable;
	always @(posedge clk)
	begin
		if(rst)
		begin
			counter_divide_select <= 2'b00;
			word_select <= 3'b000;
			tx_start_control <= 2'b00;
			receive_interrupt_enable <= 1'b0;
		end
		else if(cs & ~rs & we)
			{
				receive_interrupt_enable,
				tx_start_control,
				word_select,
				counter_divide_select
			} <= din;
	end
	
	// acia reset generation
	wire acia_rst = rst | (counter_divide_select == 2'b11);
	
	// load dout with either status or rx data
	wire [7:0] status;
	reg [7:0] rx_hold;
	always @(posedge clk)
	begin
		if(rst)
		begin
			dout <= 8'h00;
		end
		else
		begin
			if(cs & ~we)
			begin
				if(rs)
					dout <= rx_hold;
				else
					dout <= status;
			end
		end
	end
	
	// TX handling
	wire tx_load = cs & rs & we;
	always @(posedge clk)
		if(rst)
			tx_val <= 1'b0;
		else
		begin
			if(!tx_val)
				tx_val <= tx_load;
			else
				tx_val <= !tx_rdy;
		end
	
	// grab tx data
	always @(posedge clk)
		if(!tx_val & tx_load)
			tx_data <= din;
	
	// RX handling
	wire rx_clear = cs & rs & ~we;
	always @(posedge clk)
		if(rst)
			rx_rdy <= 1'b1;
		else
		begin
			if(rx_rdy)
				rx_rdy <= !rx_val;
			else
				rx_rdy <= rx_clear;
		end
	
	// grab rx data
	always @(posedge clk)
		if(rx_rdy & rx_val)
			rx_hold <= rx_data;
	
	// assemble status byte
	wire rx_err;
	assign status = 
	{
		irq,				// bit 7 = irq - forced inactive
		1'b0,				// bit 6 = parity error - unused
		1'b0,			    // bit 5 = overrun error - same as all errors
		1'b0,			    // bit 4 = framing error - same as all errors
		1'b0,				// bit 3 = /CTS - forced active
		1'b0,				// bit 2 = /DCD - forced active
		!tx_val,			// bit 1 = tx empty
		!rx_rdy				// bit 0 = receive full
	};
	
	// generate IRQ
	assign irq = (!rx_rdy & receive_interrupt_enable) | ((tx_start_control==2'b01) & !tx_val);

endmodule
