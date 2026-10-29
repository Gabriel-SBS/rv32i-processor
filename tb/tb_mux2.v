`timescale 1ns/1ps
module tb_mux2;

  reg         s;
  reg  [31:0] a, b;
  wire [31:0] o;

  reg  [31:0] expected;
  integer errors = 0;
  integer checks = 0;
  integer i;

  mux2 dut (.s(s), .a(a), .b(b), .o(o));

  task check;
    begin
      #1;
      checks = checks + 1;
      if (o !== expected) begin
        errors = errors + 1;
        $display("[ERRO] s=%b a=%h b=%h -> o=%h, esperado=%h", s, a, b, o, expected);
      end
    end
  endtask

  initial begin
    $display("  s  a         b         o");
    $monitor("  %b  %h  %h  %h", s, a, b, o);

    a = 32'hAAAA_0000; b = 32'hBBBB_0001;

    s = 1'b1; expected = 32'hAAAA_0000; check;   // s = 1 -> a
    s = 1'b0; expected = 32'hBBBB_0001; check;   // s = 0 -> b

    // muda a entrada não selecionada: a saída não pode mudar
    a = 32'h1234_5678;                  check;
    // muda a entrada selecionada: a saída acompanha
    b = 32'hFFFF_FFFF; expected = 32'hFFFF_FFFF; check;

    s = 1'b1; expected = 32'h1234_5678; check;
    b = 32'h0000_0000;                  check;   // b não selecionada
    a = 32'h8000_0001; expected = 32'h8000_0001; check;

    $monitoroff;

    // aleatório
    for (i = 0; i < 200; i = i + 1) begin
      s = $random; a = $random; b = $random;
      expected = s ? a : b;
      check;
    end

    if (errors == 0)
      $display("tb_mux2: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_mux2: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
