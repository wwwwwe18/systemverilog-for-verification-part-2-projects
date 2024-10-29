//*****************************************************
// Project		: FIFO
// File			: section2_fifo_tb
// Editor		: Wenmei Wang
// Date			: 29/10/2024
// Description	: Testbench
//*****************************************************

// --------------------------------------------
// Transaction
// --------------------------------------------
class transaction;

	rand	bit			oper;	// Decide the type of operation
			bit			wr, rd;
			bit			full, empty;
			bit	[7:0]	din;
			bit	[7:0]	dout;
			
	constraint oper_ctrl {
	
		oper dist {1 :/ 50, 0 :/ 50};	// 1 - write, 0 - read
	
	}

endclass

// --------------------------------------------
// Generator - generate stimulus
// --------------------------------------------
class generator;

	transaction tr;
	
	mailbox #(transaction) mbx;		// Send data to driver

	event next;						// Know when to send next transaction
	event done;						// Convey completion of requested number of transaction
	
	int count = 0;					// Stimulus count
	int i = 0;						// Current iteration count
	
	// Custom constructor
	function new(mailbox #(transaction) mbx);
	
		this.mbx = mbx;
		tr = new();
	
	endfunction
	
	task run();
	
		repeat(count) begin
		
			assert(tr.randomize) else $error("[GEN] : RANDOMIZATION FAILED");
			i++;
			mbx.put(tr);
			$display("[GEN] : Oper : %d Iteration : %d", tr.oper, i);
			@(next);				// Wait until the scoreboard completes its process to generate the new stimuli
		
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
	virtual fifo_if fif;			// Interface

	function new(mailbox #(transaction) mbx);
	
		this.mbx = mbx;
	
	endfunction
	
	// Reset DUT
	task reset();
	
		fif.rst	<= 1'b1;
		fif.wr	<= 1'b0;
		fif.rd	<= 1'b0;
		fif.din	<= 0;
		repeat(5) @(posedge fif.clk);
		fif.rst	<= 1'b0;
		@(posedge fif.clk);
		$display("----------------------------------------");
		$display("[DRV] : DUT RESET DONE");
		$display("----------------------------------------");
	
	endtask
	
	task write();
	
		// 3 delays in total
		@(posedge fif.clk);
		fif.rst	<= 1'b0;
		fif.wr	<= 1'b1;
		fif.rd	<= 1'b0;
		fif.din	<= $urandom_range(1, 10);
		@(posedge fif.clk);
		fif.wr	<= 1'b0;
		$display("[DRV] : DATA WRITE data : %0d", fif.din);
		@(posedge fif.clk);
	
	endtask
	
	task read();
	
		// 3 delays in total
		@(posedge fif.clk);
		fif.rst	<= 1'b0;
		fif.wr	<= 1'b0;
		fif.rd	<= 1'b1;
		@(posedge fif.clk);
		fif.rd	<= 1'b0;
		$display("[DRV] : DATA READ");
		@(posedge fif.clk);
	
	endtask
	
	// Apply stimuli received from a generator to a DUT
	task run();
	
		forever begin
		
			mbx.get(tr);		// Receive the data from a generator
			
			if(tr.oper == 1'b1)
			
				write();
				
			else
			
				read();
		
		end
	
	endtask

endclass

// --------------------------------------------
// Monitor: receive the response of DUT and then send it to a scoreboard
// --------------------------------------------
class monitor;

	transaction tr;	
	mailbox #(transaction) mbx;
	virtual fifo_if fif;

	function new(mailbox #(transaction) mbx);
	
		this.mbx = mbx;
	
	endfunction

	task run();
	
		tr = new();
		
		forever begin
		
			// 3 delays in total
			repeat(2) @(posedge fif.clk);	// Opposite to driver
			tr.wr		= fif.wr;			// tr belongs to OOP
			tr.rd		= fif.rd;
			tr.din		= fif.din;
			tr.empty	= fif.empty;
			tr.full		= fif.full;
			@(posedge fif.clk);
			tr.dout		= fif.dout;
			
			mbx.put(tr);					// Send data to a scoreboard
			$display("[MON] : wr : %0d rd : %0d din : %0d dout : %0d empty : %0d full : %0d", tr.wr, tr.rd, tr.din, tr.dout, tr.empty, tr.full);
		
		end
	
	endtask

endclass

// --------------------------------------------
// Scoreboard: receive the data from both generator (golden data) as well as monitor then perform a comparison
// --------------------------------------------
class scoreboard;

	transaction tr;				// Store data from monitor
	
	mailbox #(transaction) mbx;

	event next;					// Notify to a generator once the process of comparison completed
	
	bit	[7:0]	din[$];			// Queue for din
	bit	[7:0]	temp;
	int	err = 0;
	
	function new(mailbox #(transaction) mbx);
	
		this.mbx = mbx;
	
	endfunction

	task run();
	
		forever begin
		
			mbx.get(tr);		// Receive the data from monitor
			
			$display("[SCO] : wr : %0d rd : %0d din : %0d dout : %0d empty : %0d full : %0d", tr.wr, tr.rd, tr.din, tr.dout, tr.empty, tr.full);
			
			// Write
			if(tr.wr == 1'b1) begin
			
				if(tr.full == 1'b0) begin
				
					din.push_front(tr.din);
					$display("[SCO] : DATA STORED IN QUEUE : %0d", tr.din);
				
				end
				else begin
				
					$display("[SCO] : FIFO IS FULL");
				
				end
			
			end
			
			// Read
			if(tr.rd == 1'b1) begin
			
				if(tr.empty == 1'b0) begin
				
					temp = din.pop_back();	// The very first data written in the queue
					
					// Perform a comparison
					if(tr.dout == temp)
					
						$display("[SCO] : DATA MATCH");
						
					else begin
					
						$display("[SCO] : DATA MISMATCH");
						err++;
					
					end
				
				end
				else begin
				
					$display("[SCO] : FIFO IS EMPTY");
				
				end
			
			end
				
			$display("----------------------------------------");
			-> next;			// Notify generator to send the next stimuli
		
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
	
	virtual fifo_if fif;
	
	function new(virtual fifo_if fif);
	
		gdmdx = new();
		
		gen = new(gdmdx);
		drv = new(gdmdx);
		
		msmdx = new();
		
		mon = new(msmdx);
		sco = new(msmdx);
		
		this.fif = fif;		// Set the virtual interface for DUT
		drv.fif = this.fif;	// Connect the virtual interface to the driver
		mon.fif = this.fif;	// Connect the virtual interface to the monitor
		
		gen.next = next;	// Set the communication event between generator and scoreboard
		sco.next = next;	// Set the communication event between scoreboard and generator
	
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
		$display("----------------------------------------");
		$display("Error Count: %0d", sco.err);
		$display("----------------------------------------");
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

	fifo_if fif();	// Interface
	
	fifo dut (.clk(fif.clk), .rst(fif.rst), .wr(fif.wr), .rd(fif.rd), .din(fif.din), .dout(fif.dout), .empty(fif.empty), .full(fif.full));	// DUT
	
	initial begin
	
		fif.clk <= 0;
	
	end
	
	always #10 fif.clk <= ~fif.clk;
	
	environment env;			// Create environment instance
	
	initial begin
	
		env = new(fif);			// Initialize the environment with the DUT interface
		env.gen.count = 10;		// Set the generator's stimulus count
		env.run();				// Run the environment
	
	end

	/*
	// Display waveform on EPWave
	initial begin
	
		$dumpfile("dump.vcd");	// Specify the VCD dump file
		$dumpvars;				// Dump all variables
	
	end
	*/

endmodule