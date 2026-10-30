`timescale 1ns/1ps

module tb_regfile_alu;

  localparam ADD  = 4'b0000, SUB  = 4'b0001, AND  = 4'b0010, OR   = 4'b0011,
             XOR  = 4'b0100, SLL  = 4'b0101, SRL  = 4'b0110, SRA  = 4'b0111,
             EQ   = 4'b1000, ULT  = 4'b1001, UGTE = 4'b1010, SLT  = 4'b1011,
             SGTE = 4'b1100, NE   = 4'b1101;

  localparam N_RAND = 5000;

  reg         clk = 0, rst_n = 0, we = 0, ALUSrc = 0;
  reg  [3:0]  ALUControl = ADD;
  reg  [4:0]  rs1 = 0, rs2 = 0, rd = 0;
  reg  [31:0] imm = 0;
  wire [31:0] result;

  reg  [31:0] model [0:31];
  integer errors = 0, checks = 0;
  integer i;

  always #5 clk = ~clk;

  regfile_alu dut (
    .clk(clk), .rst_n(rst_n), .we(we), .ALUSrc(ALUSrc), .ALUControl(ALUControl),
    .rs1(rs1), .rs2(rs2), .rd(rd), .imm(imm), .result(result)
  );

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

  // executa uma instrução: confere o resultado antes da borda e atualiza o modelo depois
  task op(input [3:0] c, input [4:0] d, input [4:0] s1, input [4:0] s2,
          input src, input [31:0] im, input wen);
    reg [31:0] exp;
    begin
      @(negedge clk);
      ALUControl = c; rd = d; rs1 = s1; rs2 = s2; ALUSrc = src; imm = im; we = wen;
      #1;
      exp = ref_alu(model[s1], src ? im : model[s2], c);
      checks = checks + 1;
      if (result !== exp) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("[ERRO] t=%0t op=%b rd=x%0d rs1=x%0d rs2=x%0d src=%b imm=%h -> %h, esperado %h",
                   $time, c, d, s1, s2, src, im, result, exp);
      end
      @(posedge clk);
      if (wen && d != 0) model[d] = exp;
      #1 we = 0;
    end
  endtask

  task check_reg(input [4:0] r);
    op(ADD, 5'd0, r, 5'd0, 1'b1, 32'd0, 1'b0);
  endtask

  initial begin
    for (i = 0; i < 32; i = i + 1) model[i] = 32'd0;

    repeat (2) @(posedge clk);
    #1 rst_n = 1;

    for (i = 0; i < 32; i = i + 1) check_reg(i);

    // addi xi, x0, valor
    for (i = 1; i < 32; i = i + 1) op(ADD, i, 5'd0, 5'd0, 1'b1, $random, 1'b1);
    for (i = 0; i < 32; i = i + 1) check_reg(i);

    // escrita em x0 deve ser ignorada
    op(ADD, 5'd0, 5'd1, 5'd0, 1'b1, 32'hDEAD_BEEF, 1'b1);
    check_reg(0);

    // we = 0 não escreve
    op(XOR, 5'd5, 5'd5, 5'd0, 1'b1, 32'hFFFF_FFFF, 1'b0);
    check_reg(5);

    // dependência: o resultado de uma instrução é usado na seguinte
    op(ADD, 5'd10, 5'd0, 5'd0, 1'b1, 32'd7,  1'b1);
    op(ADD, 5'd10, 5'd10, 5'd10, 1'b0, 32'd0, 1'b1);
    op(SUB, 5'd11, 5'd10, 5'd0, 1'b1, 32'd20, 1'b1);
    op(SRA, 5'd12, 5'd11, 5'd0, 1'b1, 32'd1,  1'b1);
    op(SLT, 5'd13, 5'd11, 5'd10, 1'b0, 32'd0, 1'b1);

    for (i = 0; i < N_RAND; i = i + 1)
      op($unsigned($random) % 14, $random, $random, $random, $random, $random, $random);

    for (i = 0; i < 32; i = i + 1) check_reg(i);

    // reset no meio da execução zera tudo
    @(negedge clk) rst_n = 0;
    @(posedge clk);
    #1 rst_n = 1;
    for (i = 0; i < 32; i = i + 1) model[i] = 32'd0;
    for (i = 0; i < 32; i = i + 1) check_reg(i);

    if (errors == 0)
      $display("tb_regfile_alu: PASSOU (%0d verificacoes)", checks);
    else
      $display("tb_regfile_alu: FALHOU (%0d erros em %0d verificacoes)", errors, checks);
    $finish;
  end

endmodule
