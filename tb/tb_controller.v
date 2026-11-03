`timescale 1ns/1ps
// Unidade de controle: confere os sinais de cada opcode do RV32I, com branch_taken = 0 e 1.
// A tabela esperada vem do significado de cada sinal no datapath:
//   rs1_sel: 0 = rs1, 1 = PC          rs2_sel: 0 = rs2, 1 = imediato
//   REG_sel: 0 = memória, 1 = ULA, 2 = imediato, 3 = PC + 4
//   PC_sel:  0 = PC + 4, 1 = ULA (jalr), 2 = PC + imm, 3 = PC parado
//   halt:    1 em ecall/ebreak (o processador para)
// Sinais que não importam para uma instrução (por exemplo, REG_sel em store)
// ficam fora da comparação pela máscara.
module tb_controller;

  localparam R     = 7'b0110011, I     = 7'b0010011, LW   = 7'b0000011,
             SW    = 7'b0100011, B     = 7'b1100011, LUI  = 7'b0110111,
             AUIPC = 7'b0010111, JAL   = 7'b1101111, JALR = 7'b1100111,
             FENCE = 7'b0001111, SYSTEM = 7'b1110011;

  reg  [6:0] opcode;
  reg        branch_taken;
  wire [1:0] PC_sel, REG_sel, ALU_Op;
  wire       we_mem, we_reg, rs1_sel, rs2_sel, halt;

  // {halt, PC_sel, REG_sel, ALU_Op, we_mem, we_reg, rs1_sel, rs2_sel}
  wire [10:0] got = {halt, PC_sel, REG_sel, ALU_Op, we_mem, we_reg, rs1_sel, rs2_sel};
  reg  [10:0] exp, mask;

  integer errors = 0;
  integer checks = 0;
  integer op, lsb;

  controller dut (
    .opcode(opcode), .branch_taken(branch_taken),
    .PC_sel(PC_sel), .REG_sel(REG_sel), .ALU_Op(ALU_Op),
    .we_mem(we_mem), .we_reg(we_reg), .rs1_sel(rs1_sel), .rs2_sel(rs2_sel), .halt(halt)
  );

  // monta exp e mask para o opcode e o branch_taken atuais
  task expected;
    begin
      //                  ht    PC     REG    ALUOp  wm    wr    s1    s2
      case (opcode)
        R:      begin exp = {1'b0, 2'd0, 2'd1, 2'b10, 1'b0, 1'b1, 1'b0, 1'b0}; mask = 11'b1_11_11_11_1111; end
        I:      begin exp = {1'b0, 2'd0, 2'd1, 2'b11, 1'b0, 1'b1, 1'b0, 1'b1}; mask = 11'b1_11_11_11_1111; end
        LW:     begin exp = {1'b0, 2'd0, 2'd0, 2'b00, 1'b0, 1'b1, 1'b0, 1'b1}; mask = 11'b1_11_11_11_1111; end
        SW:     begin exp = {1'b0, 2'd0, 2'd0, 2'b00, 1'b1, 1'b0, 1'b0, 1'b1}; mask = 11'b1_11_00_11_1111; end
        B:      begin exp = {1'b0, branch_taken ? 2'd2 : 2'd0,
                                         2'd0, 2'b01, 1'b0, 1'b0, 1'b0, 1'b0}; mask = 11'b1_11_00_11_1111; end
        LUI:    begin exp = {1'b0, 2'd0, 2'd2, 2'b00, 1'b0, 1'b1, 1'b0, 1'b0}; mask = 11'b1_11_11_00_1100; end
        AUIPC:  begin exp = {1'b0, 2'd0, 2'd1, 2'b00, 1'b0, 1'b1, 1'b1, 1'b1}; mask = 11'b1_11_11_11_1111; end
        JAL:    begin exp = {1'b0, 2'd2, 2'd3, 2'b00, 1'b0, 1'b1, 1'b0, 1'b0}; mask = 11'b1_11_11_00_1100; end
        JALR:   begin exp = {1'b0, 2'd1, 2'd3, 2'b00, 1'b0, 1'b1, 1'b0, 1'b1}; mask = 11'b1_11_11_11_1111; end
        // fence: só avança o PC
        FENCE:  begin exp = {1'b0, 2'd0, 2'd0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0}; mask = 11'b1_11_00_00_1100; end
        // ecall/ebreak: para com o PC parado, sem escrever nada
        SYSTEM: begin exp = {1'b1, 2'd3, 2'd0, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0}; mask = 11'b1_11_00_00_1100; end
        // opcode não suportado: não pode escrever nada, desviar nem parar
        default: begin exp = 11'b0_00_00_00_0000; mask = 11'b1_11_00_00_1100; end
      endcase
    end
  endtask

  task check;
    begin
      #1;
      expected;
      checks = checks + 1;
      if ((got & mask) !== (exp & mask)) begin
        errors = errors + 1;
        $display("[ERRO] opcode=%b lsb=%b -> halt=%b PC_sel=%0d REG_sel=%0d ALU_Op=%b we_mem=%b we_reg=%b rs1_sel=%b rs2_sel=%b",
                 opcode, branch_taken, halt, PC_sel, REG_sel, ALU_Op, we_mem, we_reg, rs1_sel, rs2_sel);
        $display("       esperado  halt=%b PC_sel=%0d REG_sel=%0d ALU_Op=%b we_mem=%b we_reg=%b rs1_sel=%b rs2_sel=%b (mascara %b)",
                 exp[10], exp[9:8], exp[7:6], exp[5:4], exp[3], exp[2], exp[1], exp[0], mask);
      end
    end
  endtask

  initial begin
    $display("  opcode   lsb ht PC REG ALUOp wm wr s1 s2");
    $monitor("  %b  %b   %b  %0d  %0d   %b    %b  %b  %b  %b",
             opcode, branch_taken, halt, PC_sel, REG_sel, ALU_Op, we_mem, we_reg, rs1_sel, rs2_sel);

    // as 11 classes de instrução, com desvio tomado e não tomado
    for (lsb = 0; lsb < 2; lsb = lsb + 1) begin
      branch_taken = lsb;
      opcode = R;     check;
      opcode = I;     check;
      opcode = LW;    check;
      opcode = SW;    check;
      opcode = B;     check;
      opcode = LUI;   check;
      opcode = AUIPC; check;
      opcode = JAL;   check;
      opcode = JALR;  check;
      opcode = FENCE; check;
      opcode = SYSTEM; check;
    end

    $monitoroff;

    // todos os 128 opcodes: os inválidos não podem escrever, desviar nem parar
    for (op = 0; op < 128; op = op + 1)
      for (lsb = 0; lsb < 2; lsb = lsb + 1) begin
        opcode = op; branch_taken = lsb;
        check;
      end

    if (errors == 0)
      $display("tb_controller: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_controller: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
