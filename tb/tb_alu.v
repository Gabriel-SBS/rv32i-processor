module tb_alu;

  reg  [31:0] a, b;
  reg  [3:0]  opcode;
  wire [31:0] result;

  reg  [31:0] expected;
  integer errors = 0;
  integer checks = 0;

  localparam ADD  = 4'b0000,
             SUB = 4'b0001,
             AND = 4'b0010,
             OR  = 4'b0011,
             XOR  = 4'b0100,
             SLL = 4'b0101,
             SRL = 4'b0110,
             SRA = 4'b0111,
             EQ   = 4'b1000, 
             ULT = 4'b1001, 
             UGTE = 4'b1010, 
             SLT = 4'b1011,
             SGTE = 4'b1100,
             NE  = 4'b1101;

  alu dut (.a(a), .b(b), .ALU_Control(opcode), .result(result));

  always @(a or b or opcode) begin
    #5;
    checks = checks + 1;
    if (result !== expected) begin
      errors = errors + 1;
      $display("[ERRO] opcode=%b a=%h b=%h -> result=%h, esperado=%h",
               opcode, a, b, result, expected);
    end
  end

  initial begin
    $display("  opcode  a         b         result");
    $monitor("  %b    %h  %h  %h", opcode, a, b, result);
    // ADD e SUB
    opcode = ADD;  a = 32'd5;          b = 32'd7;          expected = 32'd12;          #10;
    opcode = ADD;  a = 32'hFFFF_FFFF;  b = 32'd1;          expected = 32'd0;           #10; // estouro sem sinal
    opcode = ADD;  a = 32'h7FFF_FFFF;  b = 32'd1;          expected = 32'h8000_0000;   #10; // estouro com sinal
    opcode = ADD;  a = 32'hFFFF_FFFB;  b = 32'd3;          expected = 32'hFFFF_FFFE;   #10; // -5 + 3 = -2
    opcode = SUB;  a = 32'd12;         b = 32'd5;          expected = 32'd7;           #10;
    opcode = SUB;  a = 32'd0;          b = 32'd1;          expected = 32'hFFFF_FFFF;   #10; // 0 - 1 = -1

    // Lógica
    opcode = AND;  a = 32'hF0F0_F0F0;  b = 32'h0FF0_FF00;  expected = 32'h00F0_F000;   #10;
    opcode = OR;   a = 32'hF0F0_0000;  b = 32'h000F_0F0F;  expected = 32'hF0FF_0F0F;   #10;
    opcode = XOR;  a = 32'hFFFF_0000;  b = 32'hFF00_FF00;  expected = 32'h00FF_FF00;   #10;
    opcode = XOR;  a = 32'h1234_5678;  b = 32'h1234_5678;  expected = 32'd0;           #10;

    // Deslocamento
    opcode = SLL;  a = 32'd1;          b = 32'd31;         expected = 32'h8000_0000;   #10;
    opcode = SLL;  a = 32'h0000_00FF;  b = 32'd4;          expected = 32'h0000_0FF0;   #10;
    opcode = SLL;  a = 32'd1;          b = 32'd33;         expected = 32'd2;           #10; // usa só b[4:0] = 1
    opcode = SRL;  a = 32'h8000_0000;  b = 32'd31;         expected = 32'd1;           #10;
    opcode = SRL;  a = 32'hF000_0000;  b = 32'd4;          expected = 32'h0F00_0000;   #10; // entra 0
    opcode = SRA;  a = 32'hF000_0000;  b = 32'd4;          expected = 32'hFF00_0000;   #10; // entra o sinal
    opcode = SRA;  a = 32'h7000_0000;  b = 32'd4;          expected = 32'h0700_0000;   #10; // positivo

    // Comparações (resultado 1 = verdadeiro, 0 = falso)
    opcode = EQ;   a = 32'hABCD_0001;  b = 32'hABCD_0001;  expected = 32'd1;           #10;
    opcode = EQ;   a = 32'hABCD_0001;  b = 32'hABCD_0002;  expected = 32'd0;           #10;
    opcode = NE;   a = 32'hABCD_0001;  b = 32'hABCD_0002;  expected = 32'd1;           #10;
    opcode = NE;   a = 32'hABCD_0001;  b = 32'hABCD_0001;  expected = 32'd0;           #10;
    opcode = ULT;  a = 32'd1;          b = 32'hFFFF_FFFF;  expected = 32'd1;           #10; // 1 < 4294967295
    opcode = ULT;  a = 32'd7;          b = 32'd7;          expected = 32'd0;           #10;
    opcode = UGTE; a = 32'd7;          b = 32'd7;          expected = 32'd1;           #10;
    opcode = UGTE; a = 32'd0;          b = 32'd1;          expected = 32'd0;           #10;
    opcode = SLT;  a = 32'hFFFF_FFFF;  b = 32'd1;          expected = 32'd1;           #10; // -1 < 1
    opcode = SLT;  a = 32'd1;          b = 32'hFFFF_FFFF;  expected = 32'd0;           #10; // 1 < -1 ? não
    opcode = SGTE; a = 32'd5;          b = 32'd5;          expected = 32'd1;           #10;
    opcode = SGTE; a = 32'hFFFF_FFFE;  b = 32'hFFFF_FFFF;  expected = 32'd0;           #10; // -2 >= -1 ? não

    // verifica se for um código não usado vai ser 0
    opcode = 4'b1111; a = 32'h1234_5678; b = 32'd1;       expected = 32'd0;           #10;

    if (errors == 0)
      $display("tb_alu: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_alu: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
