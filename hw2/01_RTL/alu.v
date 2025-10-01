module alu #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input   [2:0]               i_op,
    input   [DATA_WIDTH-1:0]    i_data_a,
    input   [DATA_WIDTH-1:0]    i_data_b,
    output  [DATA_WIDTH-1:0]    o_data,
    output                      o_overflow
);

    reg     [DATA_WIDTH-1:0]    tmp; 

// define ops
`define ALU_ADD 3'd0
`define ALU_SUB 3'd1

always @ (*) begin
    case (i_op)
        `ALU_ADD: begin
            tmp = i_data_a + i_data_b;
            o_data = tmp;
            o_overflow = (i_data_a[DATA_WIDTH-1] == i_data_b[DATA_WIDTH-1]) && (i_data_a[DATA_WIDTH-1] != tmp[DATA_WIDTH-1]);
        end
        `ALU_SUB: begin
            i_data_b = ~(i_data_b) + 1;
            tmp = i_data_a + i_data_b;
            o_data = tmp;
            o_overflow = (i_data_a[DATA_WIDTH-1] == i_data_b[DATA_WIDTH-1]) && (i_data_a[DATA_WIDTH-1] != tmp[DATA_WIDTH-1]);
        end

    endcase
end

endmodule