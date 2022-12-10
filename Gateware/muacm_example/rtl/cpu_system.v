// cpu_system.v - 6502 soft core system
// 12-07-22 E. Brombaugh

`default_nettype none

module cpu_system(
	input wire clk,
	input wire rst,
	input wire [7:0] rx_data,
	output wire rx_rdy,
	input wire rx_val,
	output wire [7:0] tx_data,
	input wire tx_rdy,
	output wire tx_val,
	input wire [7:0] gpio_i,
	output reg [7:0] gpio_o
);
//`define loopback
`ifdef loopback
	// Simple loopback
	assign tx_data   = rx_data;
	assign tx_val  = tx_val;
	assign rx_rdy = tx_rdy;
`else
    // The 6502
    wire [15:0] CPU_AB;
    reg [7:0] CPU_DI;
    wire [7:0] CPU_DO;
    wire CPU_WE, CPU_IRQ;
    cpu_65c02 ucpu(
        .clk(clk),
        .reset(rst),
        .AB(CPU_AB),
        .DI(CPU_DI),
        .DO(CPU_DO),
        .WE(CPU_WE),
        .IRQ(CPU_IRQ),
        .NMI(1'b0),
        .RDY(1'b1)
    );
    
	// address decode - not fully decoded for 512-byte memories
	wire sel_ram0 = (CPU_AB[15] == 1'b0) ? 1 : 0;
	wire sel_ram1 = ((CPU_AB[15:12] >= 4'h8)&&(CPU_AB[15:12] <= 4'hC)) ? 1 : 0;
	wire sel_acia = (CPU_AB[15:8] == 8'hf0) ? 1 : 0;
	wire sel_gpio = (CPU_AB[15:8] == 8'hf2) ? 1 : 0;
	wire sel_rom  = (CPU_AB[15:11] == 5'h1f) ? 1 : 0;
	
	// RAM write protects
	reg [7:0] ram0_wp, ram1_wp;
	
	// 32kB RAM @ 0000-7FFF
	wire [7:0] ram0_do;
	ram_32kb uram0(
		.clk(clk),
		.sel(sel_ram0),
		.we(CPU_WE),
		.wp(ram0_wp),
		.addr(CPU_AB[14:0]),
		.din(CPU_DO),
		.dout(ram0_do)
	);
	
	// 20kB RAM @ 8000-CFFF
	wire [7:0] ram1_do;
	ram_32kb uram1(
		.clk(clk),
		.sel(sel_ram1),
		.we(CPU_WE),
		.wp(ram1_wp),
		.addr(CPU_AB[14:0]),
		.din(CPU_DO),
		.dout(ram1_do)
	);
	
	// ACIA @ F000-F0FF
	wire [7:0] acia_do;
	usb_acia uacia(
		.clk(clk),				// system clock
		.rst(rst),				// system reset
		.cs(sel_acia),			// chip select
		.we(CPU_WE),			// write enable
		.rs(CPU_AB[0]),			// register select
		.din(CPU_DO),			// data bus input
		.dout(acia_do),			// data bus output
		.rx_data(rx_data),		// AXI interface to MUACM
		.rx_rdy(rx_rdy),
		.rx_val(rx_val),
		.tx_data(tx_data),
		.tx_rdy(tx_rdy),
		.tx_val(tx_val),
		.irq(CPU_IRQ)			// interrupt request
	);
	
	// 256B GPIO & write protects @ F200-F2FF
	reg [7:0] gpio_do;
	// write
	always @(posedge clk)
		if(rst)
		begin
			gpio_o <= 8'h00;
			ram0_wp <= 8'h00;
			ram1_wp <= 8'h00;
		end
		else if(CPU_WE & sel_gpio)
		begin
			case(CPU_AB[1:0])
				2'b00: gpio_o <= CPU_DO;
				2'b10: ram0_wp <= CPU_DO;
				2'b11: ram1_wp <= CPU_DO;
			endcase
		end
		
	// read
	always @(posedge clk)
		if(!CPU_WE & sel_gpio)
			case(CPU_AB[1:0])
				2'b00: gpio_do <= gpio_o;
				2'b01: gpio_do <= gpio_i;
				2'b10: gpio_do <= ram0_wp;
				2'b11: gpio_do <= ram1_wp;
			endcase
			
	// 2kB ROM @ F800-FFFF
    reg [7:0] rom_mem[2047:0];
	reg [7:0] rom_do;
	initial
        $readmemh("rom.hex",rom_mem);
	always @(posedge clk)
		rom_do <= rom_mem[CPU_AB[10:0]];

	// data mux
	reg [3:0] mux_sel;
	always @(posedge clk)
		mux_sel <= {sel_rom,sel_gpio,sel_acia,sel_ram1,sel_ram0};
	always @(*)
		casez(mux_sel)
			5'b00001: CPU_DI = ram0_do;
			5'b00010: CPU_DI = ram1_do;
			5'b00100: CPU_DI = acia_do;
			5'b01000: CPU_DI = gpio_do;
			5'b10000: CPU_DI = rom_do;
			default: CPU_DI = rom_do;
		endcase
`endif
endmodule
