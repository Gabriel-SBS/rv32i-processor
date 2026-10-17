module pc (clk, rst, a, o);
  input             clk, rst;   // rst ativo em nível baixo
  input      [31:0] a;          // próximo PC
  output reg [31:0] o;          // PC atual

  always @(posedge clk or negedge rst) begin
    if (!rst)
      o <= 32'd0;
    else
      o <= a;
  end

endmodule
