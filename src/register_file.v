// micro68k (reduced Motorola 68000) FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//    
// Copyright 2023-2024 by Michael Kohn

module register_file
(
  input raw_clk,
  input [31:0] index,
  input write_enable,
  input [31:0] data_in,
  output [31:0] data_out,
);

reg [31:0] storage [31:0];

always @(posedge raw_clk) begin
  if (write_enable)
    storage[index] <= data_in;
  else
    data_out <= storage[index];
end

endmodule

