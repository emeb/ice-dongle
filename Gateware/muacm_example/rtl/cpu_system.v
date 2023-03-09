// cpu_system.v - 6502 soft core system
// 12-07-22 E. Brombaugh

`default_nettype none

module cpu_system(
	input wire clk,
	input wire rst,
	
	// USB ACIA interface
	input wire [7:0] rx_data,
	output wire rx_rdy,
	input wire rx_val,
	output wire [7:0] tx_data,
	input wire tx_rdy,
	output wire tx_val,
	
	// SPI
	inout	wire spi0_mosi,
			spi0_miso,
			spi0_sclk,
			spi0_cs0,
			spi0_cs1,
	
	// GPIO
	input wire [7:0] gpio_i,
	output reg [7:0] gpio_o,
	
	// RGB
	output wire [2:0] rgb_pad
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
    wire CPU_WE, CPU_IRQ, CPU_RDY;
    cpu_65c02 ucpu(
        .clk(clk),
        .reset(rst),
        .AB(CPU_AB),
        .DI(CPU_DI),
        .DO(CPU_DO),
        .WE(CPU_WE),
        .IRQ(CPU_IRQ),
        .NMI(1'b0),
        .RDY(CPU_RDY)
    );
    
	// address decode - not fully decoded for 512-byte memories
	wire sel_ram0 = (CPU_AB[15] == 1'b0) ? 1 : 0;
	wire sel_ram1 = ((CPU_AB[15:12] >= 4'h8)&&(CPU_AB[15:12] <= 4'hC)) ? 1 : 0;
	wire sel_acia = (CPU_AB[15:8] == 8'hf0) ? 1 : 0;
	wire sel_wb   = (CPU_AB[15:8] == 8'hf1) ? 1 : 0;
	wire sel_gpio = (CPU_AB[15:8] == 8'hf2) ? 1 : 0;
	wire sel_time = (CPU_AB[15:8] == 8'hf3) ? 1 : 0;
	wire sel_rgb  = (CPU_AB[15:8] == 8'hf4) ? 1 : 0;
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
	wire acia_irq;
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
		.irq(acia_irq)			// interrupt request
	);
	
	// 256B Wishbone bus master and SB IP cores @ F100-F1FF
	wire [7:0] wb_do;
	wire wb_irq, wb_rdy;
	system_bus usysbus(
		.clk(clk),				// system clock
		.rst(rst),				// system reset
		.cs(sel_wb),			// chip select
		.we(CPU_WE),			// write enable
		.addr(CPU_AB[7:0]),		// address
		.din(CPU_DO),			// data bus input
		.dout(wb_do),			// data bus output
		.rdy(wb_rdy),			// processor stall
		.irq(wb_irq),			// interrupt request
		.spi0_mosi(spi0_mosi),	// spi core 0 mosi
		.spi0_miso(spi0_miso),	// spi core 0 miso
		.spi0_sclk(spi0_sclk),	// spi core 0 sclk
		.spi0_cs0(spi0_cs0),	// spi core 0 cs
		.spi0_cs1(spi0_cs1)		// spi core 0 cs
	);
	
	// combine IRQs
	assign CPU_IRQ = acia_irq | wb_irq;
	
	// combine RDYs
	assign CPU_RDY = wb_rdy;
	
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
	
	// 32-bit microsecond timer
	reg [4:0] prescale;
	reg [31:0] timer;
	always @(posedge clk)
		if(rst)
		begin
			prescale <= 5'b0;
			timer <= 32'b0;
		end
		else
		begin
			if(prescale == 5'd23)
			begin
				prescale <= 5'd0;
				timer <= timer + 1;
			end
			else
				prescale <= prescale + 1;
		end
		
	// read
	reg [7:0] time_do;
	always @(posedge clk)
		if(!CPU_WE & sel_time)
			case(CPU_AB[1:0])
				2'b00: time_do <= timer[7:0];
				2'b01: time_do <= timer[15:8];
				2'b10: time_do <= timer[23:16];
				2'b11: time_do <= timer[31:24];
			endcase
	// RGB LED driver is write-only
	rgb_driver urgb(
		.clk(clk),				// system clock
		.rst(rst),				// system reset
		.cs(sel_rgb),			// chip select
		.we(CPU_WE),			// write enable
		.addr(CPU_AB[4:0]),		// 5-bit address
		.din(CPU_DO),			// 8-bit data bus input
		.rgb_pad(rgb_pad)
	);
			
	// 2kB ROM @ F800-FFFF
    reg [7:0] rom_mem[2047:0];
	reg [7:0] rom_do;
	initial
        $readmemh("rom.hex",rom_mem);
	always @(posedge clk)
		rom_do <= rom_mem[CPU_AB[10:0]];

	// data mux
	reg [7:0] mux_sel;
	always @(posedge clk)
		if(CPU_RDY)
			mux_sel <= {sel_rom,sel_time,sel_gpio,sel_wb,sel_acia,sel_ram1,sel_ram0};
	always @(*)
		casez(mux_sel)
			7'b0000001: CPU_DI = ram0_do;
			7'b000001Z: CPU_DI = ram1_do;
			7'b00001ZZ: CPU_DI = acia_do;
			7'b0001ZZZ: CPU_DI = wb_do;
			7'b001ZZZZ: CPU_DI = gpio_do;
			7'b01ZZZZZ: CPU_DI = time_do;
			7'b1ZZZZZZ: CPU_DI = rom_do;
			default: CPU_DI = rom_do;
		endcase
`endif
endmodule
