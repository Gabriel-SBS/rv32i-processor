module tb_mux4;

  reg  [1:0]  s;
  reg  [31:0] a, b, c, d;
  wire [31:0] o;

  reg  [31:0] expected;
  integer errors = 0;
  integer checks = 0;

  mux4 dut (.s(s), .a(a), .b(b), .c(c), .d(d), .o(o));

  always @(s or a or b or c or d) begin
    #5;
    checks = checks + 1;
    if (o !== expected) begin
      errors = errors + 1;
      $display("[ERRO] s=%b -> o=%h, esperado=%h", s, o, expected);
    end
  end

  initial begin
    $display("  s   o");
    $monitor("  %b  %h", s, o);

    a = 32'hAAAA_0000; b = 32'hBBBB_0001; c = 32'hCCCC_0002; d = 32'hDDDD_0003;

    s = 2'b00; expected = 32'hAAAA_0000; #10;
    s = 2'b01; expected = 32'hBBBB_0001; #10;
    s = 2'b10; expected = 32'hCCCC_0002; #10;
    s = 2'b11; expected = 32'hDDDD_0003; #10;
    s = 2'b00; expected = 32'hAAAA_0000; #10;

    // muda uma entrada que não está selecionada: a saída não pode mudar
    c = 32'h1234_5678;                    #10;
    // muda a entrada selecionada: a saída acompanha
    a = 32'hFFFF_FFFF; expected = 32'hFFFF_FFFF; #10;

    $monitoroff;
    if (errors == 0)
      $display("tb_mux4: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_mux4: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
