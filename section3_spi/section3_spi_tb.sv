//*****************************************************
// Project		: SPI
// File			: section3_spi_tb
// Editor		: Wenmei Wang
// Date			: 31/10/2024
// Description	: Testbench
//*****************************************************

// --------------------------------------------
// Transaction
// --------------------------------------------
class transaction;

	rand	bit	[11:0]	din;
	
	bit			newd;
	bit	[11:0]	dout;
	bit			done;
	
	function transaction copy();	// Deep copy
	
		copy = new();
		copy.din	= this.din;
		copy.newd	= this.newd;
		copy.dout	= this.dout;
		copy.done	= this.done;
	
	endfunction

endclass

// --------------------------------------------
// Generator - generate stimulus
// --------------------------------------------
class generator;

	transaction tr;
	
	mailbox #(transaction) mbx;		// Send data to driver

	event done;						// Convey completion of requested number of transaction
	
	event drvnext;
	event sconext;
	
	int count = 0;					// Stimulus count
	
	// Custom constructor
	function new(mailbox #(transaction) mbx);
	
		this.mbx = mbx;
		tr = new();
	
	endfunction
	
	task run();
	
		repeat(count) begin
		
			assert(tr.randomize) else $error("[GEN] : RANDOMIZATION FAILED");
			mbx.put(tr.copy);	// Send deep copy to driver
			$display("[GEN] DIN : %0d", tr.din);
			//@(drvnext);
			@(sconext);
		
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
	mailbox #(bit [11:0]) mbxds;	// Driver to scoreboard
	
	virtual spi_if vif;				// Interface
	
	event drvnext;
	
	bit	[11:0]	din;

	function new(mailbox #(transaction) mbx, mailbox #(bit [11:0]) mbxds);
	
		this.mbx = mbx;
		this.mbxds = mbxds;
	
	endfunction
	
	// Reset DUT
	task reset();
	
		vif.rst		<= 1'b1;
		vif.newd	<= 1'b0;
		vif.din		<= 12'd0;
		repeat(10) @(posedge vif.clk);
		vif.rst	<= 1'b0;
		repeat(5) @(posedge vif.clk);
		$display("----------------------------------------");
		$display("[DRV] : DUT RESET DONE");
		$display("----------------------------------------");
	
	endtask
	
	// Apply stimuli received from a generator to a DUT
	task run();
	
		forever begin
		
			mbx.get(tr);			// Receive the data from a generator
			
			// 2 x sclk, 1 x done
			vif.rst		<= 1'b0;
			vif.newd	<= 1'b1;
			vif.din		<= tr.din;
			@(posedge vif.sclk);
			vif.newd	<= 1'b0;
			@(posedge vif.sclk);
			// Wait for completion
			mbxds.put(tr.din);		// Send data to scoreboard for comparison
			$display("[DRV] : DATA SENT TO DAC: %0d", tr.din);
			@(posedge vif.done);
			
			//-> drvnext;
		
		end
	
	endtask

endclass

// --------------------------------------------
// Monitor: receive the response of DUT and then send it to a scoreboard
// --------------------------------------------
class monitor;

	transaction tr;	
	mailbox #(bit [11:0]) mbx;
	virtual spi_if vif;

	function new(mailbox #(bit [11:0]) mbx);
	
		this.mbx = mbx;
	
	endfunction

	task run();
	
		tr = new();
		
		forever begin
		
			// 2 x sclk, 1 x done
			@(posedge vif.sclk);
			@(posedge vif.done);
			tr.dout = vif.dout;
			
			@(posedge vif.sclk);
			
			$display("[MON] : DATA SEND %0d", tr.dout);
			mbx.put(tr.dout);			// Send to scoreboard
		
		end
	
	endtask

endclass

// --------------------------------------------
// Scoreboard: receive the data from both generator (golden data) as well as monitor then perform a comparison
// --------------------------------------------
class scoreboard;

	mailbox #(bit [11:0]) mbxms, mbxds;

	event sconext;	// Notify to a generator once the process of comparison completed
	
	bit	[11:0]	ms;	// mon -> sco
	bit	[11:0]	ds;	// drv -> sco
	
	function new(mailbox #(bit [11:0]) mbxms, mailbox #(bit [11:0]) mbxds);
	
		this.mbxms = mbxms;
		this.mbxds = mbxds;
	
	endfunction

	task run();
	
		forever begin
		
			mbxds.get(ds);
			mbxms.get(ms);
			
			$display("[SCO] : DRV : %0d MON : %0d", ds, ms);
			
			if(ds == ms)
			
				$display("DATA MATCHED");
				
			else
			
				$display("DATA MISMATCHED");
				
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
	
	event nextgd;	// gen -> drv
	event nextgs;	// gen -> sco
	
	mailbox #(transaction) mdxgd;	// gen - drv
	
	mailbox #(bit [11:0]) mdxds;		// drv - sco
	mailbox #(bit [11:0]) mdxms;		// mon - sco
	
	virtual spi_if vif;
	
	function new(virtual spi_if vif);
	
		mdxgd = new();
		mdxds = new();
		mdxms = new();
		
		gen = new(mdxgd);
		drv = new(mdxgd, mdxds);
		
		mon = new(mdxms);
		sco = new(mdxms, mdxds);
		
		this.vif = vif;			// Set the virtual interface for DUT
		drv.vif = this.vif;		// Connect the virtual interface to the driver
		mon.vif = this.vif;		// Connect the virtual interface to the monitor
		
		gen.sconext = nextgs;	// Set the communication event between generator and scoreboard
		sco.sconext = nextgs;	// Set the communication event between scoreboard and generator
		
		gen.drvnext = nextgd;
		drv.drvnext = nextgd;
	
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

	spi_if vif();	// Interface

	spi dut
	(
		.clk(vif.clk),
		.rst(vif.rst),
		.newd(vif.newd),
		.din(vif.din),
		.dout(vif.dout),
		.done(vif.done)
	);
	
	assign vif.sclk = dut.spi_m.sclk;
	
	initial begin
	
		vif.clk <= 0;
	
	end
	
	always #10 vif.clk <= ~vif.clk;
	
	environment env;			// Create environment instance
	
	initial begin
	
		env = new(vif);			// Initialize the environment with the DUT interface
		env.gen.count = 10;		// Set the generator's stimulus count
		env.run();				// Run the environment
	
	end

	// Display waveform on EPWave
	initial begin
	
		$dumpfile("dump.vcd");	// Specify the VCD dump file
		$dumpvars;				// Dump all variables
	
	end

endmodule