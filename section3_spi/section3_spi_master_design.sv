//*****************************************************
// Project		: SPI master
// File			: section3_spi_master_design
// Editor		: Wenmei Wang
// Date			: 31/10/2024
// Description	: Design
//*****************************************************

// Master
module spi_m (

	input	clk, rst, newd,
	input	[11:0]	din,
	output	reg		cs,
	output	reg		mosi,
	output	reg 	sclk

);

	typedef enum logic [1:0] {idle = 2'b00, enable = 2'b01, send = 2'b10, comp = 2'b11} state_type;
	state_type state = idle;
	
	int countc = 0;	// Count for sclk
	int count = 0;	// Count for bit
	
	// Generating sclk = (1/20) * clk
	always@(posedge clk) begin
	
		if(rst == 1'b1) begin
		
			countc	<= 0;
			sclk	<= 1'b0;
		
		end
		else begin
		
			if(countc < 10) begin	// fclk / 20
			
				countc	<= countc + 1;
			
			end
			else begin
			
				countc	<= 0;
				sclk	<= ~sclk;
			
			end
		
		end
	
	end
	
	// State machine
	
	reg	[11:0]	temp;
	
	always@(posedge sclk) begin
	
		if(rst == 1'b1) begin
		
			cs		<= 1'b1;
			mosi	<= 1'b0;
		
		end
		else begin
		
			case(state)
			
				idle: begin
				
					if(newd == 1'b1) begin
					
						cs		<= 1'b0;
						temp	<= din;
						state	<= send;
					
					end
					else begin
					
						temp	<= 8'h00;
						state	<= idle;
					
					end
				
				end
				
				send: begin
				
					if(count <= 11) begin
					
						mosi	<= temp[count];	// Send LSB first
						count	<= count + 1;
						
					end
					else begin
					
						cs		<= 1'b1;
						mosi	<= 1'b0;
						count	<= 0;
						state	<= idle;
					
					end
				
				end
				
				default: state <= idle;
		
			endcase
		
		end
	
	end

endmodule

interface spi_m_if;

	logic			clk;
	logic			rst;
	logic			newd;
	logic	[11:0]	din;
	logic			cs;
	logic			mosi;
	logic			sclk;

endinterface