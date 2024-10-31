//*****************************************************
// Project		: Assignment 4
// File			: section3_a4_tb_demo
// Editor		: Wenmei Wang
// Date			: 31/10/2024
// Description	: Testbench
//*****************************************************

// Create a testbench environment for validating the SPI interface's ability to transmit data serially immediately when the CS signal goes low. Utilize the negative edge of the SCLK to sample the MOSI signal in order to generate reference data.

module tb;

	reg				clk = 0, rst = 0, newd = 0;
	reg		[11:0]	din = 0;
	wire			sclk, cs, mosi;
	reg		[11:0]	mosi_out;

	always #10 clk = ~clk;

	spi_master dut (clk, rst, newd, din, sclk, cs, mosi);
	 
	initial begin

		rst = 1;
		repeat(5) @(posedge clk);
		rst = 0;

		newd = 1;
		din = $urandom;
		$display("%0d", din); 
		
		for(int i = 0; i <= 11; i++) begin
		
			@(negedge dut.sclk);
			mosi_out = {mosi, mosi_out[11:1]};
			$display("%0d", mosi_out);
			
		end
		
	end

	initial begin

		$dumpfile("dump.vcd");
		$dumpvars;
		#2500;
		$stop;
		
	end

endmodule