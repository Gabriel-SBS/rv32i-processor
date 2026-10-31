`timescale 1ns/1ps
module tb_pc;

  reg         clk, rst;
  reg  [31:0] a;
  wire [31:0] o;

  reg  [31:0] expected;   // valor esperado do PC depois da próxima borda de subida
  integer errors = 0;
  integer checks = 0;

  pc dut (.clk(clk), .rst_n(rst), .a(a), .o(o));

  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Confere o PC logo depois de cada borda de subida
  always @(posedge clk) begin
    #1;
    checks = checks + 1;
    if (o !== expected) begin
      errors = errors + 1;
      $display("[ERRO] t=%0t rst=%b a=%h -> o=%h, esperado=%h", $time, rst, a, o, expected);
    end
  end

  initial begin
    $display("  tempo  rst  a         o");
    $monitor("  %4t   %b    %h  %h", $time, rst, a, o);

    // reset ativo (rst = 0): PC fica em 0 mesmo com a != 0
    rst = 1'b0; a = 32'h0000_AAAA; expected = 32'd0;
    @(negedge clk);
    @(negedge clk);

    // rst = 1: PC carrega a em cada borda de subida
    rst = 1'b1; a = 32'd4;          expected = 32'd4;          @(negedge clk);
                a = 32'd8;          expected = 32'd8;          @(negedge clk);
                a = 32'h0000_0100;  expected = 32'h0000_0100;  @(negedge clk);
                a = 32'hFFFF_FFFC;  expected = 32'hFFFF_FFFC;  @(negedge clk);

    // PC não muda entre as bordas, mesmo se a mudar
    a = 32'h0000_0055; #2;
    checks = checks + 1;
    if (o !== 32'hFFFF_FFFC) begin
      errors = errors + 1;
      $display("[ERRO] PC mudou sem borda de clock: o=%h", o);
    end
    expected = 32'h0000_0055; @(negedge clk);

    // reset assíncrono: PC vai a 0 na hora, sem esperar o clock
    rst = 1'b0; #1;
    checks = checks + 1;
    if (o !== 32'd0) begin
      errors = errors + 1;
      $display("[ERRO] reset assincrono falhou: o=%h", o);
    end
    expected = 32'd0; @(negedge clk);

    // sai do reset e volta a contar
    rst = 1'b1; a = 32'd4; expected = 32'd4; @(negedge clk);

    $monitoroff;
    if (errors == 0)
      $display("tb_pc: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_pc: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
