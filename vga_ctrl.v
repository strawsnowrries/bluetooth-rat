`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// VGA verilog template
// Author:  Da Cheng
//////////////////////////////////////////////////////////////////////////////////
module vga_demo(clk, reset, x_coordinate, y_coordinate, vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b);
	input clk;
	input reset;
	input[9:0] x_coordinate;
	input[9:0] y_coordinate;
	output vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b;
	reg vga_r, vga_g, vga_b;

	//////////////////////////////////////////////////////////////////////////////////////////

	wire inDisplayArea;
	wire [9:0] CounterX;
	wire [9:0] CounterY;

	hvsync_generator syncgen(.clk(clk), .reset(reset), .vga_h_sync(vga_h_sync), .vga_v_sync(vga_v_sync), .inDisplayArea(inDisplayArea), .CounterX(CounterX), .CounterY(CounterY));

	/////////////////////////////////////////////////////////////////
	///////////////		VGA control starts here		/////////////////
	/////////////////////////////////////////////////////////////////
	reg [9:0] positionX;
	reg [9:0] positionY;

	always @(posedge clk) begin
		positionX <= x_coordinate;
		positionY <= y_coordinate;
	end
	
	reg is_cursor;


	reg R = 1;
	reg G = 1;
	reg B = 1;

	always @(posedge clk)
	begin
		is_cursor = CounterY>=(positionY-3) && CounterY<=(positionY+3) && CounterX>=(positionX-3) && CounterX<=(positionX+3);
		if (is_cursor) begin
			vga_r <= 0 & inDisplayArea;
			vga_g <= 0 & inDisplayArea;
			vga_b <= 0 & inDisplayArea;
		end else begin
			vga_r <= R & inDisplayArea;
			vga_g <= G & inDisplayArea;
			vga_b <= B & inDisplayArea;
		end
		
	end

	/////////////////////////////////////////////////////////////////
	//////////////  	  VGA control ends here 	 ///////////////////
	/////////////////////////////////////////////////////////////////
endmodule
