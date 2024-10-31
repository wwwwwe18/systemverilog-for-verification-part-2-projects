//*****************************************************
// Project		: SPI
// File			: section3_spi_tb_demo
// Editor		: Wenmei Wang
// Date			: 31/10/2024
// Description	: Testbench
//*****************************************************

`timescale 1ns / 1ps

module tb;

	reg				clk = 0, rst = 0, newd = 0;
	reg		[11:0]	din = 0;
	wire	[11:0]	dout;
	wire			done;

	always #10 clk = ~clk;

	spi dut (clk, rst, newd, din, dout, done);

	initial begin
	
		rst = 1;
		repeat(5) @(posedge clk);
		rst = 0;

		for(int i = 0; i < 10; i++)  begin
		
			newd = 1;
			din = $urandom;
			@(posedge dut.spi_m.sclk);
			newd = 0;
			@(posedge done);
			
		end

	end

endmodule