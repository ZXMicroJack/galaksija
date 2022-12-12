/* This file is part of fpga-spec by ZXMicroJack - see LICENSE.txt for moreinfo */
module char_rom_patch(output reg[7:0] q, input wire[10:0] a, input wire clk, output wire patch, input wire override);
  reg dopatch = 1'b0;
  always @(posedge clk) begin
    if (override) begin
      dopatch <= 1'b1;
      q <= 8'hzz;
      case (a[10:0])
        11'h0100: q <= 8'hff;
        11'h0127: q <= 8'hff;
        11'h0180: q <= 8'hc0;
        11'h01a7: q <= 8'h1f;
        11'h0200: q <= 8'hdf;
        11'h0227: q <= 8'hdf;
        11'h0280: q <= 8'hdd;
        11'h02a7: q <= 8'hdf;
        11'h0300: q <= 8'hdf;
        11'h0327: q <= 8'hdf;
        11'h0380: q <= 8'hd7;
        11'h03a7: q <= 8'hdf;
        11'h0400: q <= 8'hdf;
        11'h0427: q <= 8'hdf;
        11'h0480: q <= 8'hd5;
        11'h04a7: q <= 8'h5f;
        11'h0500: q <= 8'hdf;
        11'h0527: q <= 8'hdf;
        11'h0580: q <= 8'hc0;
        11'h05a7: q <= 8'h1f;
        11'h0600: q <= 8'hff;
        11'h0627: q <= 8'hff;
        11'h0680: q <= 8'hff;
        11'h06a7: q <= 8'hff;
        default: dopatch <= 1'b0;
      endcase
    end else begin
      dopatch <= 1'b0;
    end
  end
  assign patch = dopatch;

endmodule
