// define ops
`define ALU_ADD 5'd0
`define ALU_SUB 5'd1
`define ALU_SLT 5'd8
`define ALU_SRL 5'd9

module alu #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input   [4:0]               i_op,
    input   [DATA_WIDTH-1:0]    i_data_a,
    input   [DATA_WIDTH-1:0]    i_data_b,
    output  [DATA_WIDTH-1:0]    o_data,
    output                      o_overflow
);

    reg     [DATA_WIDTH-1:0]    tmp; 
    reg     [DATA_WIDTH-1:0]    o_data_r;
    reg                         o_overflow_r;
    reg     [DATA_WIDTH-1:0]    i_data_b_r; 
    
    assign o_data = o_data_r;
    assign o_overflow = o_overflow_r;

    always @ (*) begin
        case (i_op)
            `ALU_ADD, `ALU_SUB: begin
                i_data_b_r = (i_op == `ALU_ADD) ? i_data_b : ~(i_data_b) + 1;
                tmp = i_data_a + i_data_b_r;
                o_data_r = tmp;
                o_overflow_r = (i_data_a[DATA_WIDTH-1] == i_data_b_r[DATA_WIDTH-1]) && (i_data_a[DATA_WIDTH-1] != tmp[DATA_WIDTH-1]);
            end
            `ALU_SLT: begin
                o_data_r = ($signed(i_data_a) < $signed(i_data_b)) ? 32'b1 : 32'b0;
                o_overflow_r = 0;
            end
            `ALU_SRL: begin
                o_data_r = i_data_a >> i_data_b;
                o_overflow_r = 0;
            end
            default: begin
                o_data_r = 0;
                o_overflow_r = 0;
            end

        endcase
    end

endmodule