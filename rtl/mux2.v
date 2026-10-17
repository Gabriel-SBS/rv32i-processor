module mux2 (
  input         s,
  input  [31:0] a,
  input  [31:0] b,
  output [31:0] o
);
  assign o = (s) ? a : b;
endmodule
