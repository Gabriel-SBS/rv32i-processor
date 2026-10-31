`timescale 1ns/1ps
// Memória de dados: 512 palavras (2 KiB) little-endian, endereço em bytes,
// escrita síncrona na borda de subida só nos bytes do acesso (sb, sh, sw),
// leitura combinacional com extensão de sinal (lb, lh) ou de zeros (lbu, lhu)
// e reset síncrono ativo em nível baixo que zera tudo.
module tb_data_memory;

  localparam ADDR_W = 9;
  localparam BYTES  = 4 << ADDR_W;
  localparam B = 3'b000, H = 3'b001, W = 3'b010, BU = 3'b100, HU = 3'b101;

  reg                 clk = 0, rst_n = 0, we = 0;
  reg  [2:0]          funct3 = W;
  reg  [31:0]         wdata = 0;
  reg  [ADDR_W+1:0]   addr = 0;
  wire [31:0]         rdata;

  reg  [7:0] model [0:BYTES-1];   // modelo de referência, byte a byte
  integer errors = 0;
  integer checks = 0;
  integer i;
  reg [2:0] f;

  data_memory #(.ADDR_W(ADDR_W)) dut (
    .clk(clk), .rst_n(rst_n), .we(we), .funct3(funct3),
    .wdata(wdata), .addr(addr), .rdata(rdata)
  );

  always #5 clk = ~clk;

  // valor que uma leitura deve retornar, segundo o modelo
  function [31:0] ref_read(input [ADDR_W+1:0] a, input [2:0] f3);
    reg [31:0] w;
    begin
      w = {model[{a[ADDR_W+1:2], 2'd3}], model[{a[ADDR_W+1:2], 2'd2}],
           model[{a[ADDR_W+1:2], 2'd1}], model[{a[ADDR_W+1:2], 2'd0}]};
      case (f3)
        B:       ref_read = {{24{model[a][7]}}, model[a]};
        BU:      ref_read = {24'b0, model[a]};
        H:       ref_read = {{16{model[a | 1][7]}}, model[a | 1], model[a & ~1]};
        HU:      ref_read = {16'b0, model[a | 1], model[a & ~1]};
        default: ref_read = w;
      endcase
    end
  endfunction

  task check(input [31:0] exp, input [8*40-1:0] name);
    begin
      checks = checks + 1;
      if (rdata !== exp) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("[ERRO] t=%0t %0s: addr=%h funct3=%b -> rdata=%h, esperado=%h",
                   $time, name, addr, funct3, rdata, exp);
      end
    end
  endtask

  // escreve na próxima borda de subida e atualiza o modelo
  task store(input [2:0] f3, input [ADDR_W+1:0] a, input [31:0] val);
    begin
      @(negedge clk);
      we = 1; funct3 = f3; addr = a; wdata = val;
      @(posedge clk); #1;
      we = 0;
      case (f3[1:0])
        2'b00: model[a] = val[7:0];
        2'b01: begin model[a & ~1] = val[7:0]; model[a | 1] = val[15:8]; end
        default: begin
          model[a]     = val[7:0];   model[a + 1] = val[15:8];
          model[a + 2] = val[23:16]; model[a + 3] = val[31:24];
        end
      endcase
    end
  endtask

  // leitura combinacional: não espera clock
  task load(input [2:0] f3, input [ADDR_W+1:0] a, input [8*40-1:0] name);
    begin
      funct3 = f3; addr = a; #1;
      check(ref_read(a, f3), name);
    end
  endtask

  initial begin
    for (i = 0; i < BYTES; i = i + 1) model[i] = 8'd0;

    // reset síncrono: depois de uma borda com rst_n = 0, tudo lê 0
    @(posedge clk); #1;
    for (i = 0; i < BYTES; i = i + 4) load(W, i, "reset");
    @(negedge clk) rst_n = 1;

    // sw/lw em todas as palavras
    for (i = 0; i < BYTES; i = i + 4) store(W, i, 32'hA5A5_0000 ^ (i * 32'h0001_0101));
    for (i = 0; i < BYTES; i = i + 4) load(W, i, "sw/lw todas as palavras");

    // 0x400 e 0x500 são posições diferentes (antes davam aliasing)
    store(W, 'h400, 32'h0000_0005);
    store(W, 'h500, 32'h0000_0000);
    load(W, 'h400, "0x400 nao sofre aliasing com 0x500");

    // lb/lbu/lh/lhu: extensão de sinal e de zeros (0x80FF7F01 em 0x400)
    store(W, 'h400, 32'h80FF_7F01);
    load(B,  'h400, "lb 0x01");
    load(B,  'h401, "lb 0x7F");
    load(B,  'h402, "lb 0xFF");
    load(BU, 'h402, "lbu 0xFF");
    load(B,  'h403, "lb 0x80");
    load(BU, 'h403, "lbu 0x80");
    load(H,  'h400, "lh 0x7F01");
    load(H,  'h402, "lh 0x80FF");
    load(HU, 'h402, "lhu 0x80FF");

    // sb e sh mudam só os bytes do acesso
    store(W, 'h404, 32'h1122_3344);
    store(B, 'h405, 32'hFFFF_FFAA);  load(W, 'h404, "sb no byte 1");
    store(H, 'h406, 32'hFFFF_BEEF);  load(W, 'h404, "sh na metade de cima");
    store(B, 'h404, 32'h0000_0077);  load(W, 'h404, "sb no byte 0");
    store(B, 'h407, 32'h0000_0001);  load(W, 'h404, "sb no byte 3");
    store(H, 'h404, 32'h0000_8001);  load(W, 'h404, "sh na metade de baixo");
    load(H, 'h404, "lh depois de sh");

    // we = 0 não escreve
    @(negedge clk);
    we = 0; funct3 = W; addr = 'h24; wdata = 32'hBAD0_BAD0;
    @(posedge clk); #1;
    load(W, 'h24, "we=0 nao escreve");

    // a escrita só acontece na borda de subida: o dado amostrado é o da borda
    @(negedge clk);
    we = 1; funct3 = W; addr = 'h30; wdata = 32'h1111_1111;
    #2 wdata = 32'h2222_2222;
    #1 check(ref_read('h30, W), "antes da borda nao escreve");
    @(posedge clk); #1;
    we = 0;
    for (i = 'h30; i < 'h34; i = i + 1) model[i] = 8'h22;
    load(W, 'h30, "escrita na borda de subida");

    // leitura combinacional: trocar endereço e funct3 muda rdata sem clock
    @(negedge clk);
    load(W, 'h000, "leitura combinacional 0");
    load(W, BYTES - 4, "leitura combinacional ultima palavra");
    load(B, 'h402, "leitura combinacional lb");

    // aleatório contra o modelo
    for (i = 0; i < 2000; i = i + 1) begin
      f = $random;
      case (f[1:0])
        2'b00:   store(B, $random, $random);
        2'b01:   store(H, $random & ~1, $random);
        default: store(W, $random & ~3, $random);
      endcase
      case ($unsigned($random) % 5)
        0: load(B,  $random,      "aleatorio lb");
        1: load(BU, $random,      "aleatorio lbu");
        2: load(H,  $random & ~1, "aleatorio lh");
        3: load(HU, $random & ~1, "aleatorio lhu");
        4: load(W,  $random & ~3, "aleatorio lw");
      endcase
    end

    // reset no meio da operação zera toda a memória
    @(negedge clk) rst_n = 0;
    @(posedge clk); #1;
    for (i = 0; i < BYTES; i = i + 1) model[i] = 8'd0;
    for (i = 0; i < BYTES; i = i + 4) load(W, i, "reset no meio");

    // com rst_n = 0, we = 1 não escreve (o reset tem prioridade)
    @(negedge clk);
    we = 1; funct3 = W; addr = 'h14; wdata = 32'h5555_5555;
    @(posedge clk); #1;
    we = 0;
    load(W, 'h14, "reset tem prioridade sobre we");
    @(negedge clk) rst_n = 1;

    if (errors == 0)
      $display("tb_data_memory: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_data_memory: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
