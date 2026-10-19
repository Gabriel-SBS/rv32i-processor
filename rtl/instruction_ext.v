module instruction_ext (
    input [31:0] imm,
    output [31:0] imm_ext
);
    /** Module Behavior **/
    always @(imm) begin
        case (imm[6:0])
            7'b0000011: // I-type: Load
                imm_ext = {imm[31] ? {20{1'b1}} : 20'b0 , 
				    imm[31:20]};
            
            7'b0010011: // I-type: Non-Load
                imm_ext = {imm[31] ? {20{1'b1}} : 20'b0 , 
				    imm[31:20]};
            
            7'b0100011: // S-type: Store
                imm_ext = {imm[31] ? {20{1'b1}} : 20'b0 , 
				    imm[31:25], imm[11:7]};
            
            7'b0010111: // U-type
                imm_ext = {imm [31:12], 12'b0};
                
            default: // Default: No output
                imm_ext = {32'b0};
                
        endcase
    end
endmodule