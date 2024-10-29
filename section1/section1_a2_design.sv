//*****************************************************
// Project		: Assignment 2
// File			: section1_a2_design
// Editor		: Wenmei Wang
// Date			: 29/10/2024
// Description	: Design
//*****************************************************

// Define a module named "dff" with an interface "dff_if"
module dff (dff_if vif);

	// Always block triggered on the positive edge of the clock signal
	always@(posedge vif.clk) begin

		// Check if the reset signal is asserted
		if(vif.rst == 1'b1)
		
			vif.dout <= 1'b0;		// If reset is active, set the output to 0
			
		else if(vif.din >= 1'b0)
		
			vif.dout <= vif.din;
			
		else
		
			vif.dout <= 1'b0;

	end

endmodule

// Define an interface "dff_if" with the following signals
interface dff_if;

	logic	clk;	// Clock signal
	logic	rst;	// Reset signal
	logic	din;	// Data input
	logic	dout;	// Data output

endinterface