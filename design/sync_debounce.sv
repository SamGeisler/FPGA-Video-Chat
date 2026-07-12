// Adapted from module provided for ECE 385 at the University of Illinois Urbana Champaign
// Inspired by https://forum.digikey.com/t/debounce-logic-circuit-vhdl/12573

`timescale 1ns / 1ps

module sync_debounce (
	input  logic Clk, 
	input  logic d, 

	output logic q
);

`ifdef SYNTHESIS 

localparam COUNTER_WIDTH = 15; 

logic ff1, ff2;
	logic [COUNTER_WIDTH : 0] counter;
	

	always_ff @(posedge Clk) begin
		ff1 <= d; // flop input once
		ff2 <= ff1; // flop input twice

		// Change button only when 2^(COUNTER_WIDTH) stable input cycles are recorded 
		if (~(ff1 ^ ff2)) begin // detect an input difference per clock cycle
		  if (~counter[COUNTER_WIDTH]) begin
		      counter <= counter + 1'b1; // waiting for input to become stable
		  end else begin
		      q <= ff2; // input is idle
		  end
	    end else begin
	       counter <= '0; // reset counter when bounce detected
	    end
	end

`else

assign q = d;

`endif

endmodule
