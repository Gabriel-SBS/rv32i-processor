`timescale 1ns/1ps
// Memória de dados: 64 palavras de 32 bits, escrita síncrona na borda de subida,
// leitura combinacional e reset síncrono ativo em nível baixo que zera tudo.
module tb_data_memory;

  reg         clk = 0, rst_n = 0, we = 0;
  reg  [31:0] wdata = 0;
  reg  [5:0]  addr = 0;
  wire [31:0] rdata;

  reg  [31:0] model [0:63];   // modelo de referência
  integer errors = 0;
  integer checks = 0;
  integer i;

  data_memory dut (
    .clk(clk), .rst_n(rst_n), .we(we),
    .wdata(wdata), .addr(addr), .rdata(rdata)
  );

  always #5 clk = ~clk;

  task check(input [31:0] exp, input [8*40-1:0] name);
    begin
      checks = checks + 1;
      if (rdata !== exp) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("[ERRO] t=%0t %0s: addr=%0d -> rdata=%h, esperado=%h",
                   $time, name, addr, rdata, exp);
      end
    end
  endtask

  // escreve na próxima borda de subida e atualiza o modelo
  task write(input [5:0] ad, input [31:0] val);
    begin
      @(negedge clk);
      we = 1; addr = ad; wdata = val;
      @(posedge clk); #1;
      we = 0;
      model[ad] = val;
    end
  endtask

  // leitura combinacional: não espera clock
  task read(input [5:0] ad, input [8*40-1:0] name);
    begin
      addr = ad; #1;
      check(model[ad], name);
    end
  endtask

  initial begin
    for (i = 0; i < 64; i = i + 1) model[i] = 32'd0;

    // reset síncrono: depois de uma borda com rst_n = 0, tudo lê 0
    @(posedge clk); #1;
    for (i = 0; i < 64; i = i + 1) read(i, "reset");
    @(negedge clk) rst_n = 1;

    // escreve e lê cada posição com um valor diferente
    for (i = 0; i < 64; i = i + 1) write(i, 32'hA5A5_0000 | (i * 32'h0001_0101));
    for (i = 0; i < 64; i = i + 1) read(i, "todas as posicoes");

    // sobrescrita
    write(6'd7, 32'hDEAD_BEEF);
    write(6'd7, 32'hCAFE_F00D);
    read(6'd7, "sobrescrita");

    // we = 0 não escreve
    @(negedge clk);
    we = 0; addr = 6'd9; wdata = 32'hBAD0_BAD0;
    @(posedge clk); #1;
    read(6'd9, "we=0 nao escreve");

    // a escrita só acontece na borda de subida: mudar o dado antes da borda vale
    @(negedge clk);
    we = 1; addr = 6'd12; wdata = 32'h1111_1111;
    #2 wdata = 32'h2222_2222;
    #1 check(model[12], "antes da borda nao escreve");
    @(posedge clk); #1;
    we = 0; model[12] = 32'h2222_2222;
    read(6'd12, "escrita na borda de subida");

    // leitura combinacional: trocar o endereço muda rdata sem clock
    @(negedge clk);
    addr = 6'd0;  #1 check(model[0],  "leitura combinacional 0");
    addr = 6'd63; #1 check(model[63], "leitura combinacional 63");
    addr = 6'd31; #1 check(model[31], "leitura combinacional 31");

    // valores-limite
    write(6'd0,  32'h0000_0000);  read(6'd0,  "limite 0");
    write(6'd63, 32'hFFFF_FFFF);  read(6'd63, "limite FFFFFFFF");
    write(6'd1,  32'h8000_0000);  read(6'd1,  "limite 80000000");
    write(6'd2,  32'h7FFF_FFFF);  read(6'd2,  "limite 7FFFFFFF");

    // aleatório contra o modelo
    for (i = 0; i < 1000; i = i + 1) begin
      @(negedge clk);
      we = $random; addr = $random; wdata = $random;
      @(posedge clk); #1;
      if (we) model[addr] = wdata;
      we = 0;
      addr = $random; #1;
      check(model[addr], "aleatorio");
    end

    // reset no meio da operação zera toda a memória
    @(negedge clk) rst_n = 0;
    @(posedge clk); #1;
    for (i = 0; i < 64; i = i + 1) model[i] = 32'd0;
    for (i = 0; i < 64; i = i + 1) read(i, "reset no meio");

    // com rst_n = 0, we = 1 não escreve (o reset tem prioridade)
    @(negedge clk);
    we = 1; addr = 6'd5; wdata = 32'h5555_5555;
    @(posedge clk); #1;
    we = 0;
    read(6'd5, "reset tem prioridade sobre we");
    @(negedge clk) rst_n = 1;

    if (errors == 0)
      $display("tb_data_memory: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_data_memory: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
