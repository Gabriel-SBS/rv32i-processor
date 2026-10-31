`timescale 1ns/1ps
module tb_adder;

  reg  [31:0] a, b;
  wire [31:0] o;

  reg  [31:0] expected;
  integer errors = 0;
  integer checks = 0;

  adder dut (.a(a), .b(b), .o(o));

  always @(a or b) begin
    #5;
    checks = checks + 1;
    if (o !== expected) begin
      errors = errors + 1;
      $display("[ERRO] a=%h b=%h -> o=%h, esperado=%h", a, b, o, expected);
    end
  end

  initial begin
    $display("  a         b         o");
    $monitor("  %h  %h  %h", a, b, o);

    // PC + 4
    a = 32'h0000_0000;  b = 32'd4;          expected = 32'h0000_0004;  #10;
    a = 32'h0000_0100;  b = 32'd4;          expected = 32'h0000_0104;  #10;
    a = 32'hFFFF_FFFC;  b = 32'd4;          expected = 32'h0000_0000;  #10; // dá a volta

    // PC + imm (desvio para frente e para trás)
    a = 32'h0000_0100;  b = 32'h0000_0010;  expected = 32'h0000_0110;  #10; // +16
    a = 32'h0000_0100;  b = 32'hFFFF_FFF8;  expected = 32'h0000_00F8;  #10; // -8
    a = 32'h0000_0010;  b = 32'hFFFF_F000;  expected = 32'hFFFF_F010;  #10; // -4096
    a = 32'h7FFF_FFFF;  b = 32'd1;          expected = 32'h8000_0000;  #10;
    a = 32'h1234_5678;  b = 32'd0;          expected = 32'h1234_5678;  #10; // + 0

    $monitoroff;
    if (errors == 0)
      $display("tb_adder: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_adder: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
