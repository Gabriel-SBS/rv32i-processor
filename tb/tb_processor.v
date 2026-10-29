`timescale 1ns/1ps
// Processador completo: roda um programa de instructions/programs/ e confere o
// estado final com o simulador de referência (rv32i_sim.py).
//
//   +TEST=01_alu_reg   escolhe o programa (padrão: 01_alu_reg)
//
// O programa termina no laço "fim: j fim" (0000006F). Quando o PC chega nele,
// o testbench confere:
//   - x31 == 1 (convenção dos programas: 1 = passou, 0xBAD = falhou em x30)
//   - PC de parada igual ao do simulador de referência
//   - os 32 registradores iguais aos de <TEST>.regs
// Execute a partir da pasta que contém rtl/, tb/ e instructions/.
module tb_processor;

  localparam MAX_CYCLES = 5000;
  localparam HALT       = 32'h0000_006F;   // jal x0, 0

  reg         clk = 0, rst_n = 0;
  wire [31:0] result;

  reg [8*64-1:0]  test;
  reg [8*128-1:0] hex_file, regs_file;
  reg [31:0]      expected [0:32];         // x0..x31 e PC final
  integer errors = 0;
  integer checks = 0;
  integer cycles = 0;
  integer fd, i;

  processor dut (.clk(clk), .rst_n(rst_n), .result(result));

  always #5 clk = ~clk;

  wire [31:0] pc    = dut.u_datapath.pc;
  wire [31:0] instr = dut.u_datapath.instr;

  function [31:0] reg_x(input integer r);
    reg_x = (r == 0) ? 32'd0 : dut.u_datapath.u_reg_bank.mem[r];
  endfunction

  task check(input [31:0] got, input [31:0] exp, input [8*16-1:0] name);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("[ERRO] %0s = %h, esperado %h", name, got, exp);
      end
    end
  endtask

  initial begin
    if (!$value$plusargs("TEST=%s", test)) test = "01_alu_reg";
    $sformat(hex_file,  "instructions/programs/%0s.hex",  test);
    $sformat(regs_file, "instructions/programs/%0s.regs", test);

    fd = $fopen(hex_file, "r");
    if (fd == 0) begin
      $display("tb_processor %0s: FALHOU (programa nao encontrado: %0s)", test, hex_file);
      $finish;
    end
    $fclose(fd);

    // carrega o programa por cima do HEX padrão da instruction_memory
    #1;
    for (i = 0; i < 256; i = i + 1)
      dut.u_datapath.u_instruction_memory.mem[i] = 32'd0;
    $readmemh(hex_file, dut.u_datapath.u_instruction_memory.mem);
    $readmemh(regs_file, expected);

    // reset por 2 ciclos
    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1;

    // executa até o laço final
    while (instr !== HALT && cycles < MAX_CYCLES) begin
      @(posedge clk);
      cycles = cycles + 1;
      #1;
    end

    if (instr !== HALT) begin
      errors = errors + 1;
      $display("[ERRO] %0s: nao chegou ao laco final em %0d ciclos (pc=%h instr=%h)",
               test, MAX_CYCLES, pc, instr);
    end

    check(reg_x(31), 32'd1, "x31 (status)");
    if (reg_x(31) === 32'hBAD)
      $display("[ERRO] %0s: o programa detectou falha no subteste x30 = %0d", test, reg_x(30));
    check(pc, expected[32], "pc final");
    for (i = 0; i < 32; i = i + 1)
      check(reg_x(i), expected[i], "registrador");

    if (errors != 0) begin
      $display("  registradores (DUT / esperado):");
      for (i = 0; i < 32; i = i + 1)
        if (reg_x(i) !== expected[i])
          $display("    x%0d = %h / %h", i, reg_x(i), expected[i]);
    end

    if (errors == 0)
      $display("tb_processor %0s: PASSOU (%0d verificacoes, %0d ciclos)", test, checks, cycles);
    else
      $display("tb_processor %0s: FALHOU (%0d erros em %0d verificacoes, %0d ciclos, x30=%0d)",
               test, errors, checks, cycles, reg_x(30));
    $finish;
  end

endmodule
