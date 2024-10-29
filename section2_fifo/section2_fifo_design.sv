//*****************************************************
// Project		: FIFO
// File			: section2_fifo_design
// Editor		: Wenmei Wang
// Date			: 29/10/2024
// Description	: Design
//*****************************************************

module fifo (

	input				clk, rst, wr, rd,
	input		[7:0]	din,
	output	reg	[7:0]	dout,
	output				empty, full

);

	reg	[3:0]	wptr = 0, rptr = 0;	// Pointer
	reg	[4:0]	cnt = 0;
	reg	[7:0]	mem	[15:0];			// Size, depth
	
	always@(posedge clk) begin
	
		if(rst == 1'b1) begin		// Reset
		
			wptr	<= 0;
			rptr	<= 0;
			cnt		<= 0;
		
		end
		else if(wr && !full) begin	// Write if there is space
		
			mem[wptr]	<= din;
			wptr		<= wptr + 1;
			cnt			<= cnt + 1;
	
		end
		else if(rd && !empty) begin	// Read if it is not empty
		
			dout		<= mem[rptr];
			rptr		<= rptr + 1;
			cnt			<= cnt - 1;
	
		end
	
	end
	
	assign	empty	= (cnt == 0)	? 1'b1 : 1'b0;
	assign	full	= (cnt == 16)	? 1'b1 : 1'b0;
	
endmodule

interface fifo_if;

	logic			clk, wr, rd;
	logic			rst;
	logic	[7:0]	din;
	logic	[7:0]	dout;
	logic			full, empty;

endinterface