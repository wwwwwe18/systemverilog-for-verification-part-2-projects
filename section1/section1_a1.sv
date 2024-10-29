//*****************************************************
// Project		: Assignment 1
// File			: section1_a1
// Editor		: Wenmei Wang
// Date			: 29/10/2024
// Description	: Testbench
//*****************************************************

// Modify the TB Code to Send Only 1'bx Values for All Transactions.

// --------------------------------------------
// Transaction
// --------------------------------------------
class transaction;

	rand	bit	din;
			bit	dout;
			
	function transaction copy();	// Deep copy
	
		copy = new();
		copy.din = this.din;
		copy.dout = this.dout;
	
	endfunction
	
	function void display(input string tag);
	
		$display("[%0s] : DIN : %0b DOUT : %0b", tag, din, dout);
	
	endfunction

endclass

// --------------------------------------------
// Generator - generate stimulus
// --------------------------------------------
class generator;

	transaction tr;
	
	mailbox #(transaction) mbx;		// Send data to driver
	mailbox #(transaction) mbxref;	// Send data to scoreboard for comparison / golden data

	event sconext;					// Sense completion of scoreboard work
	event done;						// Trigger once requested number of stimulus is applied
	
	int count;						// Stimulus count
	
	// Custom constructor
	function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
	
		this.mbx = mbx;
		this.mbxref = mbxref;
		tr = new();
	
	endfunction
	
	task run();
	
		repeat(count) begin
		
			//assert(tr.randomize) else $error("[GEN] : RANDOMIZATION FAILED");
			tr.din = 1'b1;
		
			mbx.put(tr.copy);		// Send the deep copy of a transaction to the driver
			mbxref.put(tr.copy);	// Send the deep copy of a transaction to the scoreboard for a comparison
			
			tr.display("GEN");
			
			@(sconext);				// Wait until the scoreboard completes its process to generate the new stimuli
		
		end
		
		-> done;
	
	endtask

endclass

// --------------------------------------------
// Driver: receive the data from a generator and apply it to a DUT with the help of an interface
// --------------------------------------------
class driver;

	transaction tr;					// Store the data received from a generator
	mailbox #(transaction) mbx;		// Receive the data from generator
	virtual dff_if vif;				// Interface

	function new(mailbox #(transaction) mbx);
	
		this.mbx = mbx;
	
	endfunction
	
	// Reset DUT
	task reset();
	
		vif.rst <= 1'b1;
		repeat(5) @(posedge vif.clk);
		vif.rst <= 1'b0;
		@(posedge vif.clk);
		$display("----------------------------------------");
		$display("[DRV] : RESET DONE");
		$display("----------------------------------------");
	
	endtask
	
	// Apply stimuli received from a generator to a DUT
	task run();
	
		forever begin
		
			mbx.get(tr);		// Receive the data from a generator
			vif.din <= tr.din;	// Use an interface to apply this data on an input port of DUT
			@(posedge vif.clk);
			tr.display("DRV");
			vif.din <= 1'b0;	// Remove the stimuli
			@(posedge vif.clk);
		
		end
	
	endtask

endclass

// --------------------------------------------
// Monitor: receive the response of DUT and then send it to a scoreboard
// --------------------------------------------
class monitor;

	transaction tr;	
	mailbox #(transaction) mbx;
	virtual dff_if vif;

	function new(mailbox #(transaction) mbx);
	
		this.mbx = mbx;
	
	endfunction

	task run();
	
		tr = new();
		
		forever begin
		
			repeat(2) @(posedge vif.clk);	// Opposite to driver
			tr.dout = vif.dout;				// tr belongs to OOP
			mbx.put(tr);					// Send data to a scoreboard
			tr.display("MON");
		
		end
	
	endtask

endclass

// --------------------------------------------
// Scoreboard: receive the data from both generator (golden data) as well as monitor then perform a comparison
// --------------------------------------------
class scoreboard;

	transaction tr;					// Store data from monitor
	transaction trref;				// Store data from generator
	
	mailbox #(transaction) mbx;
	mailbox #(transaction) mbxref;

	event sconext;					// Notify to a generator once the process of comparison completed
	
	function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
	
		this.mbx = mbx;
		this.mbxref = mbxref;
	
	endfunction

	task run();
	
		forever begin
		
			mbx.get(tr);		// Receive the data from monitor
			mbxref.get(trref);	// Receive the data from generator
			
			tr.display("SCO");
			trref.display("REF");
			
			if(tr.dout == trref.din)
			
				$display("[SCO] : DATA MATCHED");
		
			else
			
				$display("[SCO] : DATA MISMATCHED");
				
			$display("----------------------------------------");
			-> sconext;			// Notify generator to send the next stimuli
		
		end
	
	endtask

endclass

// --------------------------------------------
// Environment: static
// --------------------------------------------
class environment;

	generator	gen;
	driver		drv;
	monitor		mon;
	scoreboard	sco;
	
	event next;						// gen -> sco
	
	mailbox #(transaction) gdmdx;	// gen - drv
	mailbox #(transaction) msmdx;	// mon - sco
	mailbox #(transaction) mdxref;	// gen -> sco
	
	virtual dff_if vif;
	
	function new(virtual dff_if vif);
	
		gdmdx = new();
		mdxref = new();
		
		gen = new(gdmdx, mdxref);
		drv = new(gdmdx);
		
		msmdx = new();
		
		mon = new(msmdx);
		sco = new(msmdx, mdxref);
		
		this.vif = vif;		// Set the virtual interface for DUT
		drv.vif = this.vif;	// Connect the virtual interface to the driver
		mon.vif = this.vif;	// Connect the virtual interface to the monitor
		
		gen.sconext = next;	// Set the communication event between generator and scoreboard
		sco.sconext = next;	// Set the communication event between scoreboard and generator
	
	endfunction
	
	// Pre-test: apply the reset stimuli to a DUT
	task pre_test();
	
		drv.reset();	// Perform the driver reset
	
	endtask
	
	// Test: apply the main stimuli
	task test();
	
		fork
		
			gen.run();	// Start generator
			drv.run();	// Start driver
			mon.run();	// Start monitor
			sco.run();	// Start scoreboard
		
		join_any
	
	endtask
	
	// Post-test: wait till the simulation environment completes sending the requested number of stimuli
	task post_test();
	
		wait(gen.done.triggered);	// Wait for generator to complete
		$finish();					// Finish simulation
	
	endtask
	
	// Main task
	task run();
	
		pre_test();
		test();
		post_test();
	
	endtask

endclass

// --------------------------------------------
// TB
// --------------------------------------------
module tb;

	dff_if vif();	// Interface
	
	dff dut (vif);	// DUT
	
	initial begin
	
		vif.clk <= 0;
	
	end
	
	always #10 vif.clk <= ~vif.clk;
	
	environment env;			// Create environment instance
	
	initial begin
	
		env = new(vif);			// Initialize the environment with the DUT interface
		env.gen.count = 30;		// Set the generator's stimulus count
		env.run();				// Run the environment
	
	end

	// Display waveform on EPWave
	initial begin
	
		$dumpfile("dump.vcd");	// Specify the VCD dump file
		$dumpvars;				// Dump all variables
	
	end

endmodule