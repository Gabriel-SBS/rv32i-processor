module tb_alu_ref;

  localparam ADD  = 4'b0000, SUB  = 4'b0001, AND  = 4'b0010, OR   = 4'b0011,
             XOR  = 4'b0100, SLL  = 4'b0101, SRL  = 4'b0110, SRA  = 4'b0111,
             EQ   = 4'b1000, ULT  = 4'b1001, UGTE = 4'b1010, SLT  = 4'b1011,
             SGTE = 4'b1100, NE   = 4'b1101;

  localparam N_RAND = 20000;

  reg  [31:0] a, b;
  reg  [3:0]  op;
  wire [31:0] result;

  integer errors = 0;
  integer checks = 0;
  integer i, j, k;

  reg [31:0] edges [0:11];

  ALU dut (.a(a), .b(b), .ALUControl(op), .result(result));

  function [31:0] ref_alu(input [31:0] x, input [31:0] y, input [3:0] c);
    begin
      case (c)
        ADD:     ref_alu = x + y;
        SUB:     ref_alu = x - y;
        AND:     ref_alu = x & y;
        OR:      ref_alu = x | y;
        XOR:     ref_alu = x ^ y;
        SLL:     ref_alu = x << y[4:0];
        SRL:     ref_alu = x >> y[4:0];
        SRA:     ref_alu = $signed(x) >>> y[4:0];
        EQ:      ref_alu = (x == y);
        ULT:     ref_alu = (x < y);
        UGTE:    ref_alu = (x >= y);
        SLT:     ref_alu = ($signed(x) < $signed(y));
        SGTE:    ref_alu = ($signed(x) >= $signed(y));
        NE:      ref_alu = (x != y);
        default: ref_alu = 32'b0;
      endcase
    end
  endfunction

  task check(input [31:0] x, input [31:0] y, input [3:0] c);
    reg [31:0] exp;
    begin
      a = x; b = y; op = c;
      #1;
      exp = ref_alu(x, y, c);
      checks = checks + 1;
      if (result !== exp) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("[ERRO] op=%b a=%h b=%h -> %h, esperado %h", c, x, y, result, exp);
      end
    end
  endtask

  initial begin
    edges[0]  = 32'h0000_0000;  edges[1]  = 32'h0000_0001;
    edges[2]  = 32'h0000_0002;  edges[3]  = 32'h0000_001F;
    edges[4]  = 32'h0000_0020;  edges[5]  = 32'h7FFF_FFFE;
    edges[6]  = 32'h7FFF_FFFF;  edges[7]  = 32'h8000_0000;
    edges[8]  = 32'h8000_0001;  edges[9]  = 32'hFFFF_FFFE;
    edges[10] = 32'hFFFF_FFFF;  edges[11] = 32'hA5A5_5A5A;

    // todos os códigos (inclusive 14 e 15, que devem dar 0) x todos os pares de valores-limite
    for (k = 0; k < 16; k = k + 1)
      for (i = 0; i < 12; i = i + 1)
        for (j = 0; j < 12; j = j + 1)
          check(edges[i], edges[j], k[3:0]);

    for (k = 0; k < 32; k = k + 1) begin
      check(32'h8000_0001, k, SRA);
      check(32'h8000_0001, k, SRL);
      check(32'h8000_0001, k, SLL);
    end

    for (i = 0; i < N_RAND; i = i + 1)
      check($random, $random, $random);

    // aleatório com a == b, para cobrir os casos de igualdade
    for (i = 0; i < 1000; i = i + 1) begin
      a = $random;
      check(a, a, EQ + ($unsigned($random) % 6));
    end

    if (errors == 0)
      $display("tb_alu_ref: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_alu_ref: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
