`timescale 1ns/1ps
// Memória de dados: 2^ADDR_W palavras de 32 bits, little-endian.
// addr é o endereço em bytes; funct3 da instrução escolhe o tamanho do acesso:
//   000 lb/sb   001 lh/sh   010 lw/sw   100 lbu   101 lhu
// Escrita síncrona só nos bytes do acesso; leitura combinacional com extensão
// de sinal (lb, lh) ou de zeros (lbu, lhu). Acessos supostos alinhados.
module data_memory #(
    parameter ADDR_W = 9  // 512 palavras = 2 KiB
)(
    input                 clk,
    input                 rst_n,
    input                 we,
    input      [2:0]      funct3,
    input      [31:0]     wdata,
    input      [ADDR_W+1:0] addr,
    output reg [31:0]     rdata
);
    integer i;
    reg [31:0] mem [0:(1<<ADDR_W)-1];

    wire [ADDR_W-1:0] word = addr[ADDR_W+1:2];
    wire [1:0]        off  = addr[1:0];

    // escrita: bytes habilitados e dado replicado na posição de cada byte
    reg [3:0]  be;
    reg [31:0] wshift;
    always @(*) begin
        case (funct3[1:0])
            2'b00:   begin be = 4'b0001 << off;               wshift = {4{wdata[7:0]}};  end  // sb
            2'b01:   begin be = 4'b0011 << {off[1], 1'b0};    wshift = {2{wdata[15:0]}}; end  // sh
            default: begin be = 4'b1111;                      wshift = wdata;            end  // sw
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            // reset memory to zero
            for (i = 0; i < (1<<ADDR_W); i = i + 1) begin
                mem[i] <= 32'b0;
            end
        end
        else if (we) begin
            if (be[0]) mem[word][7:0]   <= wshift[7:0];
            if (be[1]) mem[word][15:8]  <= wshift[15:8];
            if (be[2]) mem[word][23:16] <= wshift[23:16];
            if (be[3]) mem[word][31:24] <= wshift[31:24];
        end
    end

    // leitura: seleciona o byte ou a meia palavra e estende
    wire [31:0] w = mem[word];
    wire [7:0]  b = w >> {off, 3'b000};
    wire [15:0] h = off[1] ? w[31:16] : w[15:0];

    always @(*) begin
        case (funct3)
            3'b000:  rdata = {{24{b[7]}}, b};    // lb
            3'b001:  rdata = {{16{h[15]}}, h};   // lh
            3'b100:  rdata = {24'b0, b};         // lbu
            3'b101:  rdata = {16'b0, h};         // lhu
            default: rdata = w;                  // lw
        endcase
    end
endmodule
