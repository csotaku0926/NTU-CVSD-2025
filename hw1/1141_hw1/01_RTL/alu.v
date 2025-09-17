module alu #(
    parameter INST_W = 4,
    parameter INT_W  = 6,
    parameter FRAC_W = 10,
    parameter DATA_W = INT_W + FRAC_W,
    
    parameter ACC_INT_W = 16,
    parameter ACC_FRAC_W = 20,
    parameter ACC_W = ACC_INT_W + ACC_FRAC_W
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
    reg [ACC_W-1:0]  data_acc_r, data_acc_w, multi_res_w;

    // continous assignment
    assign o_out_valid = o_out_valid_r;
    assign o_data = o_data_r;
    assign o_busy = o_busy_r;

    // procedual block
    always @ (*) begin
        case (i_inst)
            4'b0000: o_data_w = add_func(i_data_a, i_data_b);
            4'b0001: o_data_w = add_func(i_data_a, ~(i_data_b)+1);
            // cannot use function to wrap multiplication due to acc
            4'b0010: begin
                // multiply
                multi_res_w = multi_func(i_data_a, i_data_b); 
                // accumulate & saturation
                data_acc_w = multi_res_w; //add_func_ACC(data_acc_r, multi_res_w);
                // round to 16-bit
                o_data_w = round2DATA_W(data_acc_w);
            end
        endcase
        o_busy_w = 1'b0;
    end

    always @ (posedge i_clk or negedge i_rst_n) begin
        // async reset: reset at RST edge
        if (!i_rst_n) begin
            o_data_r <= 1'b0;
            o_out_valid_r <= 1'b0;
            o_busy_r <= 1'b1;
            data_acc_r <= 0;
        end
        else begin
            // start output data
            o_data_r <= o_data_w;
            o_out_valid_r <= i_in_valid;
            o_busy_r <= o_busy_w;
            data_acc_r <= data_acc_w;
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

    function [ACC_W-1:0] add_func_ACC;
        input [ACC_W-1:0] i_data_a;
        input [ACC_W-1:0] i_data_b;
        reg   [ACC_W-1:0] tmp;

        begin
            tmp = i_data_a + i_data_b;
            // overflow if a, b > 0 but tmp < 0 (vice versa)
            if (
                (i_data_a[ACC_W-1] != i_data_b[ACC_W-1]) ||
                (i_data_a[ACC_W-1] == tmp[ACC_W-1])
            ) 
            begin
                add_func_ACC = tmp;    
            end
            else if (i_data_a[ACC_W-1] == 1'b1) add_func_ACC = {1'b1, {ACC_W-1{1'b0}} }; // 100..0
            else add_func_ACC = {1'b0, {ACC_W-1{1'b1}} }; // 011..1
        end
    endfunction


    // signed multiplication
    function [ACC_W-1:0] multi_func;
        input [DATA_W-1:0] i_data_a;
        input [DATA_W-1:0] i_data_b;
        reg                  sign_r;
        reg   [ACC_W-1:0]       tmp;

        begin
            // make both data unsigned
            sign_r = 0;
            if (i_data_a[DATA_W-1] == 1'b1) begin
                i_data_a = ~(i_data_a) + 1;
                sign_r = !sign_r;
            end
            if (i_data_b[DATA_W-1] == 1'b1) begin
                i_data_b = ~(i_data_b) + 1;
                sign_r = !sign_r;
            end

            tmp = i_data_a * i_data_b; // assume it's 36 bit?
            multi_func = (sign_r) ? ~(tmp) + 1 : tmp;
        end
    endfunction

    function [DATA_W-1:0] round2DATA_W;
        input [ACC_W-1:0]  i_data;
        reg   [DATA_W-1:0] tmp;    

        begin
            // if excessive integers are not 0, then overflow
            // round to nearest
            tmp = i_data[ACC_W - (ACC_INT_W - INT_W):FRAC_W]; // 25:10
            round2DATA_W = tmp + (tmp[FRAC_W-1] ? 1 : 0); 
            // if(i_data[ACC_W-1 : int_start] == 0) begin
            //     // clamp excessive fractions
            // end

        end
    endfunction

endmodule
