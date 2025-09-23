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
    reg     [6-1:0]  cycle_cnt_r;
    reg              mat_collecting, wait2acc, done_collecting;
    reg     [DATA_W-1:0] row_mem [0:7];

    integer i;

    // continous assignment
    assign o_out_valid = o_out_valid_r;
    assign o_data = o_data_r;
    assign o_busy = o_busy_r;

    // procedual block
    always @ (posedge i_clk) begin
        o_busy_w = 1'b0;
        // valid input arrives!
        if (i_in_valid) begin
            o_out_valid_w = 1'b1;
            case (i_inst)
                4'b0000: o_data_w = add_func(i_data_a, i_data_b);
                4'b0001: o_data_w = add_func(i_data_a, ~(i_data_b)+1);
                // cannot use function to wrap multiplication due to acc
                4'b0010: begin
                    // multiply
                    multi_res_w = multi_func(i_data_a, i_data_b); 
                    // saturate acc to 36-bit
                    data_acc_w = add_ACC_func(data_acc_r, multi_res_w);
                    // signaling 
                    wait2acc = 1'b1;
                end    
                4'b0011: o_data_w = sin_func(i_data_a);
                4'b0100: o_data_w = gray_code_func(i_data_a);
                4'b0101: o_data_w = LRCW_func(i_data_a, i_data_b);
                4'b0110: o_data_w = rr_func(i_data_a, i_data_b);
                4'b0111: o_data_w = CLZ_func(i_data_a);
                4'b1000: o_data_w = RevM4_func(i_data_a, i_data_b);
                // wait for 8 cycles
                4'b1001: begin
                    mat_collecting = 1'b1;
                    row_mem[cycle_cnt_r] = i_data_a;
                end
                default: o_data_w = 0;
            endcase
        end
        else begin
            o_out_valid_w = 0;
        end
    end

    always @ (posedge i_clk or negedge i_rst_n) begin
        // async reset: reset at RST edge
        if (!i_rst_n) begin
            o_data_r <= 1'b0;
            o_out_valid_r <= 1'b0;
            o_out_valid_w <= 1'b0;
            o_busy_r <= 1'b1;
            data_acc_r <= 0;
            data_acc_w <= 0;
            multi_res_w <= 0;
            cycle_cnt_r <= 0;
            done_collecting <= 0;

            wait2acc <= 0;
            mat_collecting <= 0;
        end
        else begin
            // start output data
            o_data_r <= o_data_w;
            o_busy_r <= o_busy_w;
            o_out_valid_r <= o_out_valid_w;

            // wait for accumulate (Important! we must wait until acc to update before moving on to next inst)
            if (wait2acc) begin

                // then do rounding and saturate to 16-bit
                o_data_r <= round2DATA_W(data_acc_w);
                data_acc_r <= data_acc_w;
                wait2acc <= 1'b0;
            end

            // a valid collecting cycle
            if (mat_collecting) begin
                o_out_valid_r <= 0;
                mat_collecting <= 0;

                if (cycle_cnt_r >= 5'd7) begin
                    done_collecting <= 1;
                    o_busy_r <= 1;
                    cycle_cnt_r <= 8;
                end
                else begin
                    // // start to output 8 data without interruption
                    cycle_cnt_r <= cycle_cnt_r + 1;
                end
            end 

            if (done_collecting) begin
                if (cycle_cnt_r == 0) begin 
                    done_collecting <= 1'b0;
                    o_out_valid_r <= 0;
                    o_busy_r <= 0;
                end
                else begin
                    // output mattrans result
                    for (i=0; i<8; i=i+1) begin
                        o_data_r[15-2*i] <= row_mem[i][2*cycle_cnt_r-1];
                        o_data_r[15-2*i-1] <= row_mem[i][2*cycle_cnt_r-2];
                    end

                    cycle_cnt_r <= cycle_cnt_r - 1;
                    o_out_valid_r <= 1'b1;
                    o_busy_r <= 1'b1;
                end
            end

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

    function [ACC_W-1:0] add_ACC_func;
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
                add_ACC_func = tmp;    
            end
            else if (i_data_a[ACC_W-1] == 1'b1) add_ACC_func = {1'b1, {ACC_W-1{1'b0}} }; // 100..0
            else add_ACC_func = {1'b0, {ACC_W-1{1'b1}} }; // 011..1
        end
    endfunction

    function [ACC_W-1:0] multi_func;
        input [DATA_W-1:0] i_data_a; // 16
        input [DATA_W-1:0] i_data_b;
        reg   [ACC_W-1:0]  tmp; // 36
        reg                sign_r;
        
        begin
            sign_r = 0;
            if (i_data_a[DATA_W-1]) begin
                sign_r = ~sign_r;
                i_data_a = (~i_data_a) + 1;
            end

            if (i_data_b[DATA_W-1]) begin
                sign_r = ~sign_r;
                i_data_b = (~i_data_b) + 1;
            end

            tmp = {20'b0, i_data_a} * {20'b0, i_data_b};
            multi_func = (sign_r) ? (~tmp) + 1 : tmp; 
        end
    endfunction

    // 16 x 16 result
    function [2*DATA_W-1:0] multi_func_32;
        input [DATA_W-1:0] i_data_a;
        input [DATA_W-1:0] i_data_b;
        reg                 sign_r;
        reg   [2*DATA_W-1:0] tmp;

        begin
            sign_r = 0;
            if (i_data_a[DATA_W-1]) begin
                sign_r = ~sign_r;
                i_data_a = (~i_data_a) + 1;
            end

            if (i_data_b[DATA_W-1]) begin
                sign_r = ~sign_r;
                i_data_b = (~i_data_b) + 1;
            end

            tmp = {16'b0, i_data_a} * {16'b0, i_data_b};
            multi_func_32 = (sign_r) ? (~tmp) + 1 : tmp; 
        end
    endfunction

    // rounding
    function [DATA_W-1:0] round2DATA_W;
        input [ACC_W-1:0]  i_data;
        reg   [DATA_W-1:0] tmp;  

        begin
            // if excessive integers are not 0, then saturate them
            // 000...01_1111_ (max) ~ 111...10_0000_ (min)
            if (i_data[ACC_W-1:ACC_W-11] == { (ACC_INT_W - INT_W + 1){1'b0} } || 
                i_data[ACC_W-1:ACC_W-11] == { (ACC_INT_W - INT_W + 1){1'b1} }) 
            begin
                // round to nearest
                tmp = i_data[ACC_W - 1 - (ACC_INT_W - INT_W):FRAC_W]; // 25:10
                // if tmp == 011..1 and round up will overflow
                round2DATA_W = tmp + ((i_data[FRAC_W-1] == 1'b1 && 
                                        tmp != {1'b0, {DATA_W-1{1'b1}} }) ? 1 : 0);     
            end
            else if (i_data[ACC_W-1] == 1'b0) begin
                round2DATA_W = {1'b0, {DATA_W-1{1'b1}} }; // 011..1
            end
            else begin
                round2DATA_W = {1'b1, {DATA_W-1{1'b0}} }; // 100..0
            end
            
        end
    endfunction

    // sin function
    function [DATA_W-1:0] sin_func;
        input [DATA_W-1:0]  i_data;
        reg   [DATA_W-1:0]   reci3fact; // 1/3! 
        reg   [DATA_W-1:0]   reci5fact; // 1/5!
        reg   [2*DATA_W-1:0]   i_data_2;
        reg   [3*DATA_W-1:0]   i_data_3; 
        reg   [5*DATA_W-1:0]   i_data_5; // data power 5
        reg   [4*DATA_W-1:0]   reci3_data_3;
        reg   [6*DATA_W-1:0]   reci5_data_5, tmp;

        begin
            // sin(x) = \sum_n(0:2) (-1)^n * x^(2n+1) / (2n+1)! 
            // reciprocal
            reci3fact = { {INT_W{1'b0}}, 10'b0010101011 };
            reci5fact = { {INT_W{1'b0}}, 10'b0000001001 };

            // calc
            i_data_2 = $signed(i_data) * $signed(i_data);
            i_data_3 = $signed(i_data_2) * $signed(i_data);
            i_data_5 = $signed(i_data_2) * $signed(i_data_3);

            reci3_data_3 = $signed(i_data_3) * $signed(reci3fact);
            reci5_data_5 = $signed(i_data_5) * $signed(reci5fact);

            tmp = { {5*INT_W{1'b0}}, i_data, {5*FRAC_W{1'b0}} } 
                - {{2*INT_W{1'b0}}, reci3_data_3, {2*FRAC_W{1'b0}}}
                + reci5_data_5;
            sin_func = tmp[6*DATA_W-1 - 5 * INT_W: 5*FRAC_W] + ((tmp[5*FRAC_W-1]) ? 1 : 0);
        end
    endfunction


    function [DATA_W-1:0] gray_code_func;
        input [DATA_W-1:0] i_data;
        reg                   tmp;
        integer                 i;

        begin
            tmp = 1'b0;
            for (i=DATA_W-1; i>=0; i=i-1) begin
                gray_code_func[i] = i_data[i] ^ tmp;
                tmp = i_data[i];
            end
        end
    endfunction

    function [DATA_W-1:0] LRCW_func;
        input [DATA_W-1:0] i_data_a;
        input [DATA_W-1:0] i_data_b;
        reg                     tmp; 
        integer                   i;

        begin
            // dumb way to do popcnt
            for (i=DATA_W-1; i>=0; i=i-1) begin // loop iter must be pre-determined!
                if (i_data_a[i]) begin
                    // complement-on-wrap
                    tmp = i_data_b[DATA_W-1];
                    i_data_b = i_data_b << 1;
                    i_data_b[0] = ~tmp;
                end
            end
            LRCW_func = i_data_b;
        end
    endfunction

    // right rotation
    function [DATA_W-1:0] rr_func;
        input [DATA_W-1:0] i_data_a; // original
        input [DATA_W-1:0] i_data_b; // shift amount

        begin
            rr_func = (i_data_a >> i_data_b) | (i_data_a << (DATA_W - i_data_b));
        end
    endfunction

    // count leading zero
    function [DATA_W-1:0] CLZ_func;
        input [DATA_W-1:0] i_data;
        integer                 i;
        reg                  flag;

        begin
            CLZ_func = 0;
            flag = 1;

            for (i=DATA_W-1; i>=0; i=i-1) begin
                if (!i_data[i] && flag) CLZ_func = CLZ_func + 1;
                else flag = 0;
            end
        end
    endfunction

    // reverse match 4
    function [DATA_W-1:0] RevM4_func;
        input [DATA_W-1:0] i_data_a;
        input [DATA_W-1:0] i_data_b;
        integer                 idx;
        reg   [DATA_W-1:0]      mask;

        begin
            mask = 5'b01111;
            RevM4_func = 0;
            for (idx=DATA_W-4; idx>=0; idx=idx-1) begin
                // Verilog does not allow variable width, which sucks :(
                // be careful that integer is signed by default 
                if (((i_data_a >> idx) & mask) == ((i_data_b >> (12 - idx)) & mask) ) 
                    RevM4_func[idx] = 1; 
            end
        end
    endfunction

endmodule
