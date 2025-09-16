module alu #(
    parameter INST_W = 4,
    parameter INT_W  = 6,
    parameter FRAC_W = 10,
    parameter DATA_W = INT_W + FRAC_W
)(
    input                      i_clk,
    input                      i_rst_n,

    input                      i_in_valid,
    output                     o_busy,
    input         [INST_W-1:0] i_inst,
    input  signed [DATA_W-1:0] i_data_a,
    input  signed [DATA_W-1:0] i_data_b,

    output                     o_out_valid,
    output        [DATA_W-1:0] o_data
);

    // wires and regs
    reg [DATA_W-1:0] o_data_r, o_data_w;
    reg              o_out_valid_r, o_out_valid_w;
    reg              o_busy_r, o_busy_w;

    // continous assignment
    assign o_out_valid = o_out_valid_r;
    assign o_data = o_data_r;
    assign o_busy = o_busy_r;

    // procedual block
    always @ (*) begin
        case (i_inst)
            4'b0000: o_data_w = add_func(i_data_a, i_data_b);
            4'b0001: o_data_w = add_func(i_data_a, ~(i_data_b)+1);
        endcase
        o_busy_w = 1'b0;
    end

    always @ (posedge i_clk or negedge i_rst_n) begin
        // async reset: reset at RST edge
        if (!i_rst_n) begin
            o_data_r <= 1'b0;
            o_out_valid_r <= 1'b0;
            o_busy_r <= 1'b1;
        end
        else begin
            // start output data
            o_data_r <= o_data_w;
            o_out_valid_r <= i_in_valid;
            o_busy_r <= o_busy_w;
        end
    end

    // functions (remember to add semicolon behind declarations)
    function [DATA_W-1:0] add_func;
        input [DATA_W-1:0] i_data_a;
        input [DATA_W-1:0] i_data_b;
        reg   [DATA_W-1:0] tmp;

        begin
            tmp = i_data_a + i_data_b;
            // overflow if a, b > 0 but tmp < 0 (vice versa)
            if (
                (i_data_a[DATA_W-1] != i_data_b[DATA_W-1]) ||
                (i_data_a[DATA_W-1] == tmp[DATA_W-1])
            ) 
            begin
                add_func = tmp;    
            end
            else if (i_data_a[DATA_W-1] == 1'b1) add_func = {1'b1, {DATA_W-1{1'b0}} }; // 100..0
            else add_func = {1'b0, {DATA_W-1{1'b1}} }; // 011..1
        end
    endfunction

endmodule
