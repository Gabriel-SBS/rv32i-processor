// Banco de registradores + ULA: rd <= rs1 op (ALUSrc ? imm : rs2)
module datapath  #(
  /** Macros for signal bit counts **/
  parameter PC_W = 32,      // PC width
  parameter INSTR_W = 32,  // Instruction width
  parameter DATA_W = 32,   // Data width
  parameter DM_ADDR_W = 6, // DataMem width
  parameter ALU_CC_W = 4,   // ALU_Control width
  parameter PC_SEL_W = 2, //PC_sel width
  parameter REG_SEL_W = 2, //REG_sel width
  parameter ADDR_W = 5
  )(
  input   clk, rst_n, we_mem, we_reg, rs1_sel, rs2_sel,
  input   [ALU_CC_W-1:0]  ALU_Control,
  input   [PC_SEL_W-1:0] PC_sel,
  input   [REG_SEL_W-1:0] REG_sel,
  output  [DATA_W-1:0] result
  );

  wire [DATA_W-1:0] src_a, src_b, write_back_result, mem_o, rs1_o, rs2_o;
  wire [ADDR_W-1:0] rd, rs1, rs2;
  wire [PC_W-1:0] pc, pc_next, pc_plus4;
  wire [INSTR_W-1:0] imm, imm_ext;

  
  assign rd = imm[11:7];
  assign rs1 = imm[19:15];
  assign rs2 = imm[24:20];

  mux2 mux_src_a (.s(rs1_sel), .a(rs1_o), .b(imm_ext), .o(src_a)); // execução
  mux2 mux_src_b (.s(rs2_sel), .a(rs2_o), .b(imm_ext), .o(src_b));
  mux4 mux_write_back (.s(REG_sel), .a(mem_o), .b(result), .c(imm_ext), .d(pc_plus4), .o(write_back_result)); //write_back

  pc_logic pc_logic(.clk(clk), .rst(rst_n), .PC_sel(PC_sel), .imm(imm), .alu_result(result), .pc_o(pc), .pc_plus4(pc_plus4), .pc_next(pc_next), .pc_target());
  
  instruction_memory instruction_memory(.addr(pc_next), .data(imm));
 
  //instruction_ext instruction_ext(.imm(imm), .imm_ext(imm_ext));

  regfile rf (
    .clk(clk), .rst_n(rst_n), .we(we_reg),
    .rs1(rs1), .rs2(rs2), .rd(rd),
    .wr_rd(write_back_result),
    .rs1_o(rs1_o), .rs2_o(rs2_o)
  );

  ALU alu (.a(src_a), .b(src_b), .ALUControl(ALU_Control), .result(result));

  data_memory data_memory(.clk(clk), .rst(rst_n), .we(we_mem), .wdata(rs2_o),  .addr(result[DM_ADDR_W-1:0]), .rdata(mem_o));


endmodule
