/* This file is part of fpga-spec by ZXMicroJack - see LICENSE.txt for moreinfo */
module rom_patch(output reg[7:0] q, input wire[15:0] a, input wire clk, output wire patch, input wire override);
   reg [7:0] mem [0:36];

   initial begin
     $readmemh("dev/patch/hyperload.hex", mem);
   end

   wire valid = override && a[15:0] >= 16'h0edd && a[15:0] < 16'h0f02;
   always @(posedge clk) begin
     q <= valid ? mem[a-16'h0edd] : 8'hZZ;
   end
   assign patch = valid;

endmodule
