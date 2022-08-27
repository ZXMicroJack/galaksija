`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:04:00 04/01/2012 
// Design Name: 
// Module Name:    sigma_delta_dac 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

`define MSBI 7 										// Most significant Bit of DAC input

//This is a Delta-Sigma Digital to Analog Converter
module dac2 (clk_i, res_n_i, dac_i, dac_o);
	input 			clk_i;
	input 			res_n_i;							// active 0
	input [`MSBI:0]dac_i; 							// DAC input (excess 2**MSBI)	
	output 			dac_o; 							// This is the average output that feeds low pass filter



	reg 				 dac_o; 							// for optimum performance, ensure that this ff is in IOB
	reg [`MSBI+2:0] DeltaAdder;					// Output of Delta adder
	reg [`MSBI+2:0] SigmaAdder; 					// Output of Sigma adder
	reg [`MSBI+2:0] SigmaLatch = 1'b1<<(`MSBI+1); // Latches output of Sigma adder
	reg [`MSBI+2:0] DeltaB; 						// B input of Delta adder

	always @(SigmaLatch) DeltaB = {SigmaLatch[`MSBI+2], SigmaLatch[`MSBI+2]} << (`MSBI+1);
	always @(dac_i or DeltaB) DeltaAdder = dac_i + DeltaB;
	always @(DeltaAdder or SigmaLatch) SigmaAdder = DeltaAdder + SigmaLatch;
	always @(posedge clk_i)
	begin
		if(res_n_i == 1'b0)
		begin
			SigmaLatch <= 1'b1 << (`MSBI+1);
			dac_o      <= 1'b0;
		end
		else
		begin
			SigmaLatch <= SigmaAdder;
			dac_o      <= SigmaLatch[`MSBI+2];
		end
	end
endmodule
