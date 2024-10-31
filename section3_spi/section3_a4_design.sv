//*****************************************************
// Project		: Assignment 4
// File			: section3_a4_design
// Editor		: Wenmei Wang
// Date			: 31/10/2024
// Description	: Design
//*****************************************************

// Create a testbench environment for validating the SPI interface's ability to transmit data serially immediately when the CS signal goes low. Utilize the negative edge of the SCLK to sample the MOSI signal in order to generate reference data.

module spi_master(

	input			clk, rst, newd,
	input	[11:0]	din, 
	output	reg		sclk, cs, mosi

);

	typedef enum bit [1:0] {idle = 2'b00, enable = 2'b01, send = 2'b10, comp = 2'b11 } state_type;
	state_type state = idle;
	
	int countc = 0;
	int count = 0;
 
	// Generation of sclk
	always@(posedge clk) begin
	
		if(rst == 1'b1) begin
		
			countc <= 0;
			sclk <= 1'b0;
		  
		end
		else begin
		
			if(countc < 3 )

				countc <= countc + 1;
				  
			else begin
					
				countc <= 0;
				sclk <= ~sclk;
				
			end
			
		end
		
	end

	// State machine
    reg [11:0] temp;
	
	always@(posedge sclk) begin
	
		if(rst == 1'b1) begin
		
			cs <= 1'b1; 
			mosi <= 1'b0;
			
		end
		else begin
		
			case(state)
			
				idle: begin
				
					if(newd == 1'b1) begin
					
						state <= send;
						temp <= din; 
						cs <= 1'b0;
						mosi <= din[0];
						count <= 1;
					 
					end
					else begin
					
						state <= idle;
						temp <= 8'h00;
						
					end
				end


				send: begin
				
					if(count <= 11) begin
					
						mosi <= temp[count]; // Sending LSB first
						count <= count + 1;
						
					end
					else begin
					
						count <= 0;
						state <= idle;
						cs <= 1'b1;
						mosi <= 1'b0;
						
					end
					
				end

				default : state <= idle; 

			endcase
			
		end
	
	end

endmodule

interface spi_m_if;

	logic			clk;
	logic			rst;
	logic			newd;
	logic	[11:0]	din;
	logic			sclk;
	logic			cs;
	logic			mosi;

endinterface