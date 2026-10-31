`timescale 1ns/1ps
// Banco de registradores + ULA: rd <= rs1 op (ALUSrc ? imm : rs2)
module regfile_alu (clk, rst_n, we, ALUSrc, ALUControl, rs1, rs2, rd, imm, result);
  input         clk, rst_n, we, ALUSrc;
  input  [3:0]  ALUControl;
  input  [4:0]  rs1, rs2, rd;
  input  [31:0] imm;
  output [31:0] result;

  wire [31:0] rs1_o, rs2_o, src_b;

  reg_bank rf (
    .clk(clk), .rst_n(rst_n), .we(we),
    .rs1(rs1), .rs2(rs2), .rd(rd),
    .wr_rd(result),
    .rs1_o(rs1_o), .rs2_o(rs2_o)
  );

  mux2 mux_src_b (.s(ALUSrc), .a(imm), .b(rs2_o), .o(src_b));

  ALU u_alu (.a(rs1_o), .b(src_b), .ALUControl(ALUControl), .result(result), .branch_taken());

endmodule
