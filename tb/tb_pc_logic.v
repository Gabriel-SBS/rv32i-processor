// Sequência de PCs testada (o PC começa em 0 depois do reset):
//   0x000 -> 0x004 -> 0x008 -> 0x00C   execução sequencial   (PCSel = 0)
//   0x00C -> 0x01C                     desvio tomado, +16    (PCSel = 2)
//   0x01C -> 0x020                     sequencial
//   0x020 -> 0x018                     desvio para trás, -8  (PCSel = 2)
//   0x018 -> 0x118                     JAL, +256             (PCSel = 2)
//   0x118 -> 0x040                     JALR para 0x41 -> bit 0 zerado (PCSel = 1)
//   0x040 -> 0x200                     JALR para 0x200       (PCSel = 1)
//   0x200 -> 0x204                     PCSel = 3 (não usado) -> PC + 4
//   0x204 -> 0x208                     desvio não tomado     (PCSel = 0, imm ignorado)
//   reset assíncrono -> 0x000, depois 0x004
module tb_pc_logic;

  reg         clk, rst;
  reg  [1:0]  PCSel;
  reg  [31:0] imm, alu_result;
  wire [31:0] pc_o, pc_plus4, pc_target, pc_next;

  reg  [31:0] expected;   // valor esperado do PC depois da próxima borda de subida
  integer errors = 0;
  integer checks = 0;

  pc_logic dut (
    .clk(clk), .rst(rst), .PCSel(PCSel), .imm(imm), .alu_result(alu_result),
    .pc_o(pc_o), .pc_plus4(pc_plus4), .pc_target(pc_target), .pc_next(pc_next)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Confere o PC logo depois de cada borda de subida
  always @(posedge clk) begin
    #1;
    checks = checks + 1;
    if (pc_o !== expected) begin
      errors = errors + 1;
      $display("[ERRO] t=%0t PCSel=%b imm=%h alu=%h -> pc=%h, esperado=%h",
               $time, PCSel, imm, alu_result, pc_o, expected);
    end
  end

  initial begin
    $display("  tempo  rst PCSel imm       alu_result pc        pc+4      pc+imm");
    $monitor("  %4t   %b   %b    %h  %h   %h  %h  %h",
             $time, rst, PCSel, imm, alu_result, pc_o, pc_plus4, pc_target);

    // reset (rst = 0): PC = 0
    rst = 1'b0; PCSel = 2'd0; imm = 32'd0; alu_result = 32'd0; expected = 32'd0;
    @(negedge clk);
    @(negedge clk);

    // execução sequencial
    rst = 1'b1;
    PCSel = 2'd0;                            expected = 32'h0000_0004; @(negedge clk);
    PCSel = 2'd0;                            expected = 32'h0000_0008; @(negedge clk);
    PCSel = 2'd0;                            expected = 32'h0000_000C; @(negedge clk);

    // somadores (combinacionais) com PC = 0x00C e imm = 16
    imm = 32'h0000_0010; #1;
    checks = checks + 2;
    if (pc_plus4 !== 32'h0000_0010) begin
      errors = errors + 1; $display("[ERRO] pc_plus4=%h, esperado=00000010", pc_plus4);
    end
    if (pc_target !== 32'h0000_001C) begin
      errors = errors + 1; $display("[ERRO] pc_target=%h, esperado=0000001c", pc_target);
    end

    // desvios e saltos
    PCSel = 2'd2; imm = 32'h0000_0010;       expected = 32'h0000_001C; @(negedge clk); // desvio +16
    PCSel = 2'd0;                            expected = 32'h0000_0020; @(negedge clk); // sequencial
    PCSel = 2'd2; imm = 32'hFFFF_FFF8;       expected = 32'h0000_0018; @(negedge clk); // desvio -8
    PCSel = 2'd2; imm = 32'h0000_0100;       expected = 32'h0000_0118; @(negedge clk); // JAL +256
    PCSel = 2'd1; alu_result = 32'h0000_0041; expected = 32'h0000_0040; @(negedge clk); // JALR, bit 0 zerado
    PCSel = 2'd1; alu_result = 32'h0000_0200; expected = 32'h0000_0200; @(negedge clk); // JALR
    PCSel = 2'd3;                            expected = 32'h0000_0204; @(negedge clk); // não usado
    PCSel = 2'd0; imm = 32'h0000_0040;       expected = 32'h0000_0208; @(negedge clk); // desvio não tomado

    // reset assíncrono: PC vai a 0 na hora
    rst = 1'b0; #1;
    checks = checks + 1;
    if (pc_o !== 32'd0) begin
      errors = errors + 1; $display("[ERRO] reset assincrono falhou: pc=%h", pc_o);
    end
    expected = 32'd0; @(negedge clk);

    rst = 1'b1; PCSel = 2'd0;                expected = 32'h0000_0004; @(negedge clk);

    $monitoroff;
    if (errors == 0)
      $display("tb_pc_logic: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_pc_logic: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
