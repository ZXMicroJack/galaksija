/* This file is part of fpga-spec by ZXMicroJack - see LICENSE.txt for moreinfo */
module rom_patch(output reg[7:0] q, input wire[15:0] a, input wire clk, output wire patch, input wire override);
   reg [7:0] memload [0:36];
   reg [7:0] memsave [0:26];

   initial begin
     $readmemh("dev/patch/hyperload.hex", memload);
     $readmemh("dev/patch/hypersave.hex", memsave);
   end

   wire load = a[15:0] >= 16'h0edd && a[15:0] < 16'h0f02;
   wire save = a[15:0] >= 16'h0e68 && a[15:0] < 16'h0e82;
   wire valid = override && (load || save);
   always @(posedge clk) begin
     q <= override && load ? memload[a-16'h0edd] : 
          override && save ? memsave[a-16'h0e68] : 
          8'hZZ;
   end
   assign patch = valid;

endmodule
