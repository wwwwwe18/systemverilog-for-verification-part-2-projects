//*****************************************************
// Project		: SPI
// File			: section3_spi_design
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

// Slave
module spi_s (

	input			sclk, ss, mosi,
	output	[11:0]	dout,
	output	reg		done

);

	integer count = 0;
	
	typedef enum logic [1:0] {detect_start = 0, read_data = 1} state_type;
	state_type state = detect_start;
	
	reg	[11:0]	temp = 12'h000;
	
	always@(negedge sclk) begin
	
		case(state)
		
			detect_start: begin
			
				done	<= 1'b0;
				
				if(ss == 1'b0)
				
					state <= read_data;
					
				else
				
					state <= detect_start;
			
			end
			
			read_data: begin
			
				if(count <= 11) begin
				
					count	<= count + 1;
					temp	<= {mosi, temp[11:1]}; // RSR - master sends LSB bit first
					state	<= read_data;
				
				end
				else begin
				
					count	<= 0;
					state	<= detect_start;
					done	<= 1'b1;
				
				end
			
			end
		
			default: state <= detect_start;
		
		endcase
	
	end

	assign dout = temp;

endmodule

// Top
module spi (

	input			clk, rst, newd,
	input	[11:0]	din,
	output	[11:0]	dout,
	output			done

);

	wire mosi, cs, sclk;
	
	spi_m spi_m (clk, rst, newd, din, cs, mosi, sclk);
	spi_s spi_s (sclk, cs, mosi, dout, done);

endmodule

interface spi_if;

	logic			clk;
	logic			rst;
	logic			newd;
	logic	[11:0]	din;
	logic	[11:0]	dout;
	logic			done;
	logic			sclk;

endinterface