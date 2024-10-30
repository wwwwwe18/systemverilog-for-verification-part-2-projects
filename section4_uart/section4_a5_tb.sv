//*****************************************************
// Project		: Assignment 5
// File			: section4_a5_tb
// Editor		: Wenmei Wang
// Date			: 30/10/2024
// Description	: Testbench
//*****************************************************

// Modify the Testbench environment used for the verification of UART to test the operation of the UART transmitter with PARITY and STOP BIT. Add logic in scoreboard to verify that the data on TX pin matches the random 8-bit data applied on the DIN bus by the user.Parity is always enabled and odd type. (9600 - 8 - O - 1)

// --------------------------------------------
// Transaction
// --------------------------------------------
class transaction;

	typedef enum bit {write = 1'b0, read = 1'b1} oper_type;
	randc	oper_type	oper;	// Decide the type of operation
	
	rand	bit	[7:0]	dintx;
	
	bit			rx;
	bit			newd;
	bit			tx;
	bit	[8:0]	doutrx;
	bit			donetx;
	bit			donerx;
	
	function transaction copy();	// Deep copy
	
		copy = new();
		copy.oper	= this.oper;
		copy.dintx	= this.dintx;
		copy.rx		= this.rx;
		copy.newd	= this.newd;
		copy.tx		= this.tx;
		copy.doutrx	= this.doutrx;
		copy.donetx	= this.donetx;
		copy.donerx	= this.donerx;
	
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
			$display("[GEN] : Oper : %0s Din : %0d", tr.oper.name(), tr.dintx);
			@(drvnext);
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
	mailbox #(bit [8:0]) mbxds;		// Driver to scoreboard
	
	virtual uart_if vif;			// Interface
	
	event drvnext;
	
	bit	[8:0]	din;
	
	bit	wr = 0;			// Random operation read / write
	bit	[8:0]	datarx;	// Data rcvd during read

	function new(mailbox #(transaction) mbx, mailbox #(bit [8:0]) mbxds);
	
		this.mbx = mbx;
		this.mbxds = mbxds;
	
	endfunction
	
	// Reset DUT
	task reset();
	
		vif.rst		<= 1'b1;
		vif.dintx	<= 0;
		vif.newd	<= 0;
		vif.rx		<= 1'b1;
		repeat(5) @(posedge vif.uclktx);
		vif.rst	<= 1'b0;
		@(posedge vif.uclktx);
		$display("----------------------------------------");
		$display("[DRV] : DUT RESET DONE");
		$display("----------------------------------------");
	
	endtask
	
	// Apply stimuli received from a generator to a DUT
	task run();
	
		forever begin
		
			mbx.get(tr);					// Receive the data from a generator
			
			if(tr.oper == 1'b0) begin		// Data transmission -> write

				@(posedge vif.uclktx);
				vif.rst		<= 1'b0;
				vif.dintx	<= tr.dintx;
				vif.newd	<= 1'b1;		// Start data sending op
				vif.rx		<= 1'b1;
				@(posedge vif.uclktx);
				vif.newd	<= 1'b0;
				
				din = {~^tr.dintx, tr.dintx};
				
				// Wait for completion
				mbxds.put(din);				// Send data to scoreboard for comparison
				$display("[DRV] : DATA SENT : %0b - %0b", tr.dintx, din[8]);
				wait(vif.donetx == 1'b1);
				
				-> drvnext;
				
			end
			else if(tr.oper == 1'b1) begin	// Data transmission -> read

				@(posedge vif.uclktx);
				vif.rst		<= 1'b0;
				vif.newd	<= 1'b0;
				vif.rx		<= 1'b0;		// Start of transaction
				@(posedge vif.uclktx);
				
				for(int i = 0; i <= 7; i++) begin
				
					@(posedge vif.uclktx);
					vif.rx	<= $urandom;
					datarx[i] = vif.rx;
				
				end
				
				@(posedge vif.uclktx);
				vif.rx	<= ~^datarx[7:0];
				datarx[8] = vif.rx;
				
				// Wait for completion
				mbxds.put(datarx);			// Send data to scoreboard for comparison
				$display("[DRV] : DATA RCVD : %0b - %0b", datarx[7:0], datarx[8]);
				wait(vif.donerx == 1'b1);
				vif.rx		<= 1'b1;
				
				-> drvnext;
				
			end
		
		end
	
	endtask

endclass

// --------------------------------------------
// Monitor: receive the response of DUT and then send it to a scoreboard
// --------------------------------------------
class monitor;

	transaction tr;	
	mailbox #(bit [8:0]) mbx;
	virtual uart_if vif;
	
	bit	[8:0]	srx;	// Send
	bit	[8:0]	rrx;	// Rcvd

	function new(mailbox #(bit [8:0]) mbx);
	
		this.mbx = mbx;
	
	endfunction

	task run();
		
		forever begin
		
			@(posedge vif.uclktx);
			
			if((vif.newd == 1'b1) && (vif.rx == 1'b1)) begin	// Transmitting data
			
				@(posedge vif.uclktx);	// Start collecting tx data from next clock tick
				
				for(int i = 0; i <= 8; i++) begin
				
					@(posedge vif.uclktx);
					srx[i] = vif.tx;
				
				end
				
				$display("[MON] : DATA SEND TX %0b - %0b", srx[7:0], srx[8]);
				
				// Wait for done tx before proceeding next Transaction
				@(posedge vif.uclktx);
				mbx.put(srx);		// Send to scoreboard
			
			end
			if((vif.newd == 1'b0) && (vif.rx == 1'b0)) begin	// Receiving data
			
				wait(vif.donerx == 1);
				rrx = vif.doutrx;
			
				$display("[MON] : DATA RCVD RX %0b - %0b", rrx[7:0], rrx[8]);
				@(posedge vif.uclktx);
				mbx.put(rrx);	// Send to scoreboard
			
			end
		
		end
	
	endtask

endclass

// --------------------------------------------
// Scoreboard: receive the data from both generator (golden data) as well as monitor then perform a comparison
// --------------------------------------------
class scoreboard;

	mailbox #(bit [8:0]) mbxms;
	mailbox #(bit [8:0]) mbxds;

	event sconext;	// Notify to a generator once the process of comparison completed
	
	bit	[8:0]	ms;	// mon -> sco
	bit	[8:0]	ds;	// drv -> sco
	
	bit			par;
	
	function new(mailbox #(bit [8:0]) mbxms, mailbox #(bit [8:0]) mbxds);
	
		this.mbxms = mbxms;
		this.mbxds = mbxds;
	
	endfunction

	task run();
	
		forever begin
		
			mbxds.get(ds);
			mbxms.get(ms);
			
			$display("[SCO] : DRV : %0b - %0b MON : %0b - %0b", ds[7:0], ds[8], ms[7:0], ms[8]);
			
			if(ds[7:0] == ms[7:0])
			
				$display("DATA MATCHED");
				
			else
			
				$display("DATA MISMATCHED");
				
			if(ds[8] == ms[8])
			
				$display("PARITY MATCHED");
				
			else
			
				$display("PARITY MISMATCHED");
				
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
	
	mailbox #(bit [8:0]) mdxds;		// drv - sco
	mailbox #(bit [8:0]) mdxms;		// mon - sco
	
	virtual uart_if vif;
	
	function new(virtual uart_if vif);
	
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

	uart_if vif();	// Interface
	
	uart_top
	#(1_000_000, 9600)
	dut
	(
		.clk(vif.clk),
		.rst(vif.rst),
		.rx(vif.rx),
		.dintx(vif.dintx),
		.newd(vif.newd),
		.tx(vif.tx),
		.doutrx(vif.doutrx),
		.donetx(vif.donetx),
		.donerx(vif.donerx)
	);
	
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

	assign vif.uclktx = dut.utx.uclk;
	assign vif.uclkrx = dut.urx.uclk;

endmodule