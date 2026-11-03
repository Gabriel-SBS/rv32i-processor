`timescale 1ns/1ps
module instruction_memory #(
    parameter MEM_SIZE  = 256,                                    // palavras
    parameter INIT_FILE = "instructions/instruction_control.hex"  // programa ($readmemh)
)(
    input  wire [31:0] addr,
    output reg  [31:0] data
);
    localparam IDX_W = $clog2(MEM_SIZE);

    reg [31:0] mem [0:MEM_SIZE-1];

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    always @(*) begin
        data = mem[addr[IDX_W+1:2]];  // Assuming word-aligned addresses
    end
endmodule
