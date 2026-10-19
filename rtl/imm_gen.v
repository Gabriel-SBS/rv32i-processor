`timescale 1ns/1ps
module imm_gen (
    input  [31:0] instr,
    output reg [31:0] imm_ext
);
    /** Module Behavior **/
    always @(instr) begin
        case (instr[6:0])
            7'b0000011:  // I-type: Load
                imm_ext = {instr[31] ? {20{1'b1}} : 20'b0,
                           instr[31:20]};

            7'b0010011:  // I-type: Non-Load
                imm_ext = {instr[31] ? {20{1'b1}} : 20'b0,
                           instr[31:20]};

            7'b0100011:  // S-type: Store
                imm_ext = {instr[31] ? {20{1'b1}} : 20'b0,
                           instr[31:25], instr[11:7]};

            7'b0010111:  // U-type
                imm_ext = {instr[31:12], 12'b0};

            default:     // Default: No output
                imm_ext = {32'b0};
        endcase
    end
endmodule
