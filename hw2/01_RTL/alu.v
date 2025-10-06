// define ops
`define ALU_ADD     5'd0
`define ALU_SUB     5'd1
`define ALU_SLT     5'd2
`define ALU_SRL     5'd3
`define ALU_FCLASS  5'd4
`define ALU_FSUB    5'd5
`define ALU_FMUL    5'd6
`define ALU_FCVTWS  5'd7


module alu #(
    parameter   DATA_WIDTH = 32,
    parameter   ADDR_WIDTH = 32,
    parameter   F_EXPO_W = 8,
    parameter   F_MANT_W = 23,
    parameter   F_TMP_W = 264
) (
    input   [4:0]               i_op,
    input   [DATA_WIDTH-1:0]    i_data_a,
    input   [DATA_WIDTH-1:0]    i_data_b,
    output  [DATA_WIDTH-1:0]    o_data,
    output                      o_overflow
);

    // ALU variables
    reg     [DATA_WIDTH-1:0]    tmp; 
    reg     [DATA_WIDTH-1:0]    o_data_r;
    reg                         o_overflow_r;
    reg     [DATA_WIDTH-1:0]    i_data_b_r; 
    
    assign o_data = o_data_r;
    assign o_overflow = o_overflow_r;
    
    // floating point
    wire                        f_sign_a_w, f_sign_b_w;
    wire    [F_EXPO_W-1:0]      f_expo_a_w, f_expo_b_w;
    wire    [F_MANT_W-1:0]      f_mant_a_w, f_mant_b_w;

    assign f_sign_a_w = i_data_a[31];
    assign f_sign_b_w = i_data_b[31];
    assign f_expo_a_w = i_data_a[30:23];
    assign f_expo_b_w = i_data_b[30:23];
    assign f_mant_a_w = i_data_a[22:0];
    assign f_mant_b_w = i_data_b[22:0];

    // FP arthimetic
    wire    [F_TMP_W-1:0]             fa_ext_w, fb_ext_w;
    wire    [F_TMP_W-1:0]             fa_ext2_w, fb_ext2_w;
    reg     [F_TMP_W-1:0]             fa_tmp_r, fb_tmp_r;
    reg     [F_TMP_W-1:0]             f_res_tmp_r;
    
    assign fa_ext_w = f_mant_a_w;
    // shift by expo diff
    assign fa_ext2_w = (f_expo_a_w > f_expo_b_w) ? fa_ext_w << (f_expo_a_w - f_expo_b_w) : fa_ext_w;
    assign fb_ext_w = f_mant_b_w;
    assign fb_ext2_w = (f_expo_b_w > f_expo_a_w) ? fb_ext_w << (f_expo_b_w - f_expo_a_w) : fb_ext_w;

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

            `ALU_FCLASS: begin
                // case 1. neg inf: s=1, e=255, m=0
                if      (f_sign_a_w == 1'd1 && f_expo_a_w == 8'd255 && f_mant_a_w == 23'd0)
                    o_data_r = 0;
                // case 2. neg normal: s=1, 0 < e < 255
                else if (f_sign_a_w == 1'd1 && 8'd0 < f_expo_a_w && f_expo_a_w < 8'd255)
                    o_data_r = 1;
                // case 3. neg subnormal: s=1, e=0, m!=0
                else if (f_sign_a_w == 1'd1 && f_expo_a_w == 8'd0 && f_mant_a_w != 23'd0)
                    o_data_r = 2;
                // case 4. neg zero: s=1, e=m=0
                else if (f_sign_a_w == 1'd1 && f_expo_a_w == 8'd0 && f_expo_a_w == 23'd0)
                    o_data_r = 3;
                // case 5. pos zero: s=e=m=0
                else if (f_sign_a_w == 1'd0 && f_expo_a_w == 8'd0 && f_expo_a_w == 23'd0)
                    o_data_r = 4;
                // case 6. pos subnormal: s=e=0, m!=0
                else if (f_sign_a_w == 1'd0 && f_expo_a_w == 8'd0 && f_expo_a_w != 23'd0)
                    o_data_r = 5;
                // case 7. pos normal: s=0, 0<e<255
                else if (f_sign_a_w == 1'd0 && 8'd0 < f_expo_a_w && f_expo_a_w < 8'd255)
                    o_data_r = 6;
                // case 8. pos inf: s=0, e=255, m=0
                else if (f_sign_a_w == 1'd0 && f_expo_a_w == 8'd255 && f_mant_a_w == 23'd0)
                    o_data_r = 7;
                // case 9. NaN (sNaN and qNaN)
                else if (f_expo_a_w == 8'd255 && f_mant_a_w != 23'd0)
                    o_data_r = (f_mant_a_w[22] == 1'b0) ? 8 : 9;
                else
                    o_data_r = 0; // should not be the case

                o_overflow_r = 0;
            end
            
            `ALU_FSUB: begin
                // sign bit (note it's subtraction)
                fa_tmp_r = (f_sign_a_w) ? ~(fa_ext2_w) + 1 : fa_ext2_w;
                fb_tmp_r = (f_sign_b_w) ? fb_ext2_w : ~(fb_ext2_w) + 1;
                f_res_tmp_r = fa_tmp_r + fb_tmp_r;

                // rounding
                
            end

            default: begin
                o_data_r = 0;
                o_overflow_r = 0;
            end

        endcase
    end

endmodule

function automatic [DATA_WIDTH-1:0] round2NE;
    input [F_TMP_W-1:0] i_data;
    input [7:0]         i_shift; // expo diff
    
    begin
        // 11.111 (2) + 1.111 (1) = 101.110 (1)
        // 1.BBGSS
    end

endfunction