// define ops
`define ALU_ADD     5'd0
`define ALU_SUB     5'd1
`define ALU_SLT     5'd2
`define ALU_SRL     5'd3
`define ALU_FCLASS  5'd4
`define ALU_FSUB    5'd5
`define ALU_FMUL    5'd6
`define ALU_FCVTWS  5'd7
`define ALU_SEQ     5'd8


module alu #(
    parameter   DATA_WIDTH = 32,
    parameter   ADDR_WIDTH = 32,
    parameter   F_EXPO_W = 8,
    parameter   F_MANT_W = 23,
    parameter   F_TMP_W = 280 // normal shift max 253, + 23 + 2
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
    wire                         f_sign_a_w, f_sign_b_w;
    wire    [F_EXPO_W -1:0]      f_expo_a_w, f_expo_b_w; 
    wire    [F_EXPO_W+1 -1:0]    f_res_expo_w;
    wire    [F_MANT_W -1:0]      f_mant_a_w, f_mant_b_w;

    assign f_sign_a_w = i_data_a[31];
    assign f_sign_b_w = i_data_b[31];
    assign f_expo_a_w = i_data_a[30:23];
    assign f_expo_b_w = i_data_b[30:23];
    assign f_mant_a_w = i_data_a[22:0];
    assign f_mant_b_w = i_data_b[22:0];

// ===================== FP sub arthimetic ================================
    wire    [F_TMP_W-1:0]             fa_ext_w, fb_ext_w;
    wire    [F_TMP_W-1:0]             fa_ext2_w, fb_ext2_w;
    reg     [F_TMP_W-1:0]             fa_tmp_r, fb_tmp_r;
    reg     [F_TMP_W-1:0]             f_res_tmp_r;
    reg                               f_res_sign_r;
    wire     [1:0]                     fa_prepend_bits, fb_prepend_bits;
    wire    [F_EXPO_W -1:0]           f_nml_expo_a_w, f_nml_expo_b_w;
    
    // subnormal handling
    assign fa_prepend_bits = (f_expo_a_w > 0) ? 2'b01 : 2'b00; // normal : subnormal
    assign f_nml_expo_a_w = (f_expo_a_w > 0) ? f_expo_a_w : 1;
    assign fb_prepend_bits = (f_expo_b_w > 0) ? 2'b01 : 2'b00; // normal : subnormal
    assign f_nml_expo_b_w = (f_expo_b_w > 0) ? f_expo_b_w : 1;
    // extension
    assign fa_ext_w = { fa_prepend_bits, f_mant_a_w, {(F_TMP_W - F_MANT_W - 2){1'b0}} };
    assign fa_ext2_w = (f_nml_expo_a_w < f_nml_expo_b_w) ? fa_ext_w >> (f_nml_expo_b_w - f_nml_expo_a_w) : fa_ext_w; // shift by expo diff
    assign fb_ext_w = { fb_prepend_bits, f_mant_b_w, {(F_TMP_W - F_MANT_W - 2){1'b0}} };
    assign fb_ext2_w = (f_nml_expo_b_w < f_nml_expo_a_w) ? fb_ext_w >> (f_nml_expo_a_w - f_nml_expo_b_w) : fb_ext_w;
    // note expo are unsigned
    assign f_res_expo_w = (i_op == `ALU_FSUB) ? ((f_nml_expo_a_w > f_nml_expo_b_w) ? {1'b0, f_nml_expo_a_w} : {1'b0, f_nml_expo_b_w}) // FSUB
                            : ({1'b0, f_nml_expo_a_w} + {1'b0, f_nml_expo_b_w} - 9'd127); // FMUL

// ======================= FP mult ===================
    reg     [F_MANT_W+1:0]                  fmul_a_mant_r, fmul_b_mant_r;
    reg     [(F_MANT_W+1)*2-1:0]            fmul_mant_res_r;
    reg                                     fmul_is_zero_r;
    reg                                     guard_r, round_r, sticky_r;
    reg                                     do_round;

// FP fcvtws
    reg     [DATA_WIDTH+F_MANT_W-1:0]       fcvtws_tmp_r;
    reg     [DATA_WIDTH+F_MANT_W-1:0]       fcvtws_shifted_r;  
    reg     [DATA_WIDTH-1:0]                o_tmp_r;

    
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

            `ALU_SEQ: begin
                o_data_r = (i_data_a == i_data_b) ? 32'b1 : 32'b0;
                o_overflow_r = 0;
            end
            
            `ALU_SRL: begin
                o_data_r = i_data_a >> i_data_b;
                o_overflow_r = 0;
            end

            `ALU_FCLASS: begin
                // case 1. neg inf: s=1, e=255, m=0
                if      (f_sign_a_w == 1'd1 && f_expo_a_w == 8'd255 && f_mant_a_w == 23'd0)
                    o_data_r = 32'b1;
                // case 2. neg normal: s=1, 0 < e < 255
                else if (f_sign_a_w == 1'd1 && 8'd0 < f_expo_a_w && f_expo_a_w < 8'd255)
                    o_data_r = 32'b10;
                // case 3. neg subnormal: s=1, e=0, m!=0
                else if (f_sign_a_w == 1'd1 && f_expo_a_w == 8'd0 && f_mant_a_w != 23'd0)
                    o_data_r = 32'b100;
                // case 4. neg zero: s=1, e=m=0
                else if (f_sign_a_w == 1'd1 && f_expo_a_w == 8'd0 && f_expo_a_w == 23'd0)
                    o_data_r = 32'b1000;
                // case 5. pos zero: s=e=m=0
                else if (f_sign_a_w == 1'd0 && f_expo_a_w == 8'd0 && f_expo_a_w == 23'd0)
                    o_data_r = 32'b10000;
                // case 6. pos subnormal: s=e=0, m!=0
                else if (f_sign_a_w == 1'd0 && f_expo_a_w == 8'd0 && f_expo_a_w != 23'd0)
                    o_data_r = 32'b10_0000;
                // case 7. pos normal: s=0, 0<e<255
                else if (f_sign_a_w == 1'd0 && 8'd0 < f_expo_a_w && f_expo_a_w < 8'd255)
                    o_data_r = 32'b100_0000;
                // case 8. pos inf: s=0, e=255, m=0
                else if (f_sign_a_w == 1'd0 && f_expo_a_w == 8'd255 && f_mant_a_w == 23'd0)
                    o_data_r = 32'b1000_0000;
                // case 9. NaN (sNaN and qNaN)
                else if (f_expo_a_w == 8'd255 && f_mant_a_w != 23'd0)
                    o_data_r = (f_mant_a_w[22] == 1'b0) ? 32'b1_0000_0000 : 32'b10_0000_0000;
                else
                    o_data_r = 0; // should not be the case

                o_overflow_r = 0;
            end
            
            `ALU_FSUB: begin
                // NaN detection
                if (f_expo_a_w > 8'd254 || f_expo_b_w > 8'd254) begin
                    o_data_r = 0;
                    o_overflow_r = 1;
                end
                else begin
                    // sign bit (note it's subtraction) (TODO: make it unsigned)
                    f_res_tmp_r = (f_sign_a_w == ~f_sign_b_w) ?  fa_ext2_w + fb_ext2_w :
                                                    ((fa_ext2_w > fb_ext2_w) ? fa_ext2_w - fb_ext2_w : fb_ext2_w - fa_ext2_w);
                    f_res_sign_r = (f_sign_a_w == ~f_sign_b_w) ? f_sign_a_w : 
                                    ((fa_ext2_w > fb_ext2_w) ? f_sign_a_w : ~f_sign_b_w);

                    // rounding and detect invalid
                    {o_overflow_r, o_data_r} = round2NE(f_res_tmp_r, f_res_expo_w[7:0], f_res_sign_r);
                end
            end

            `ALU_FMUL: begin
                // NaN, INF detection
                if (f_expo_a_w > 8'd254 || f_expo_b_w > 8'd254) begin
                    o_data_r = 0;
                    o_overflow_r = 1;
                end
                else begin
                    fmul_mant_res_r = {23'b0, fa_prepend_bits, f_mant_a_w} * {23'b0, fb_prepend_bits, f_mant_b_w};
                    f_res_sign_r = f_sign_a_w ^ f_sign_b_w;
                    
                    {o_overflow_r, o_data_r} = MULround2NE(fmul_mant_res_r, f_res_expo_w[7:0], f_res_sign_r,
                                                            f_nml_expo_a_w, f_nml_expo_b_w);
                    
                    // underflow: < 1.0 * 2^-126 (subnormal counts) (exclude zero!)
                    // expo_shift = (fmul_mant_res_r[(F_MANT_W+1)*2-1] == 1'b1) ? 9'b1 : 9'b0;
                    // fmul_unsigned_expo = {1'b0, f_expo_a_w} + {1'b0, f_expo_b_w} + expo_shift;
                    // o_overflow_r =  ((fmul_unsigned_expo < 9'd1) & (o_data_r > 0))  // underflow
                    //             | (fmul_unsigned_expo > 9'd381);                    // overflow: >= 1.0 * 2^128
                    // {o_overflow_r, o_data_r} = MULround2NE(fmul_mant_res_r, f_res_expo_w, f_res_sign_r);
                end
            end

            `ALU_FCVTWS: begin
                // NaN, INF detection
                if (f_expo_a_w > 8'd254) begin
                    o_data_r = 0;
                    o_overflow_r = 1;
                end
                else if (8'd127 <= f_expo_a_w) begin
                    // normal: (-1)^s * 2^(e-127) * 1.m
                    // , if expo < 127 then {1, mantissa} will be discarded
                    fcvtws_tmp_r = { {(DATA_WIDTH-1){1'b0}}, 1'b1, f_mant_a_w };

                    // maximum shift left 30 bit; larger will overflow
                    fcvtws_shifted_r = fcvtws_tmp_r << (f_expo_a_w - 8'd127);
                    // rounding
                    guard_r = fcvtws_shifted_r[F_MANT_W]; // G: LSB of result
                    round_r = fcvtws_shifted_r[F_MANT_W-1]; // R: 1st removed
                    sticky_r = (fcvtws_shifted_r[F_MANT_W-2:0] > 0);

                    do_round = (guard_r & round_r) | (sticky_r & round_r);

                    o_tmp_r = fcvtws_shifted_r[F_MANT_W+DATA_WIDTH-1 : F_MANT_W] + do_round;
                    o_data_r = (f_sign_a_w) ? ~(o_tmp_r) + 1 : o_tmp_r;
                    // note negative 100..0 is valid
                    o_overflow_r = (f_expo_a_w > 8'd157) & ~(f_sign_a_w & ( o_data_r == { 1'b1, {(DATA_WIDTH-1){1'b0}} })); 
                end
                else begin
                    // only fractional.. no need to consider as integer
                    // subnormal: (-1)^s * 2^-126 * 0.m
                    round_r = (f_mant_a_w > 0); // R: 1st removed
                    // G = S = 1 --> o_data = 1 (G=1 if normal)
                    o_data_r = ((f_expo_a_w == 8'd126) & (round_r)) ? 32'b1 : 32'b0;
                    o_overflow_r = 0;
                end

            end

            default: begin
                o_data_r = 0;
                o_overflow_r = 0;
            end

        endcase
    end


    function automatic [DATA_WIDTH-1+1:0] round2NE;
        input [F_TMP_W-1:0]              i_data;
        input [7:0]                      i_expo; 
        input                            i_sign;

        reg   [F_MANT_W-1:0]            BBG_r;      // normal and guard bits
        reg   [F_TMP_W-F_MANT_W-1-1:0]                   remain_r;   // remaining bits
        reg                             guard_r, round_r, sticky_r;
        integer                         i, MSB_i;
        reg                             MSB_found_r;
        reg   [7:0]                      res_expo;    // expo for final result
        reg   [8:0]                      cmp_expo;    // determine overflow or not
        reg                              res_sign;
        reg                              o_invalid; // overflow or underflow
        reg                             do_round;

        begin
            // 1.1110 (2) + 0.1111 (1+1) = 10.110|1 (2)
            // left shift max 1; right shift ?
            // normalize: 1.001 - 1.0001 = -0.0001
            // search MSB
            MSB_found_r = 0;
            MSB_i = 0;
            for (i=0; i<F_TMP_W; i=i+1) begin
                if (MSB_found_r == 1'b0 && i_data[F_TMP_W-1-i] == 1'b1) begin
                    MSB_found_r = 1;
                    MSB_i = i;
                end
            end
            
            // i_data << MSB_i => normal
            
            // remove prepend leading 1
            // G: LSB of result
            // R: 1st bit removed
            {BBG_r, round_r, remain_r} = i_data << (MSB_i + 1);
            guard_r = BBG_r[0];
            // S: OR of remaining
            sticky_r = (remain_r > 0);
            
            // round 2 even
            do_round = (round_r == 1 && sticky_r == 1) | // R = S = 1 
                        (round_r == 1 && guard_r == 1);  // G = R = 1

            // underflow: expo < 1, overflow: expo > 254
            cmp_expo = {1'b0, i_expo} + 1 - {1'b0, MSB_i};
            o_invalid = ((i_expo < MSB_i) & (MSB_found_r != 0)) | 
                        (cmp_expo > 9'd254) |
                        ((cmp_expo == 9'd254) & (BBG_r == {F_MANT_W{1'b1}}) & (round_r | sticky_r));

            // is no MSB found, indicates 0
            // need to add one more expo after round up, if mant == 11..11
            res_expo = (MSB_found_r == 1) ? i_expo + 1 - MSB_i + (BBG_r == {F_MANT_W{1'b1}} & do_round) : 0 ;
            // round 2 even
            BBG_r = BBG_r + do_round;

            // set as positive zero if 0
            res_sign = (BBG_r == 0 && res_expo == 0) ? 1'b0 : i_sign;

            round2NE = {o_invalid,
                        res_sign, res_expo, BBG_r};

        end
    endfunction


    function automatic [DATA_WIDTH+1-1:0] MULround2NE;
        input [(F_MANT_W+1)*2-1:0]       i_data;
        input [7:0]                      i_expo; 
        input                            i_sign;
        input [F_EXPO_W -1:0]            f_nml_expo_a_w; 
        input [F_EXPO_W -1:0]            f_nml_expo_b_w;

        reg   [F_MANT_W-1:0]            BBG_r;      // normal and guard bits
        reg   [(F_MANT_W+1)*2-F_MANT_W-1-1:0]                   remain_r;   // remaining bits
        reg                             guard_r, round_r, sticky_r;
        reg                             o_invalid;
        reg                             do_round;
        reg                             res_sign;
        reg   [7:0]                     res_expo; 
        reg                             MSB_found_r;
        integer                         i;
        reg     [8:0]                   expo_shift, fmul_unsigned_expo;

        begin

            // remove prepend leading 1 (TODO: only for normal numbers)
            MSB_found_r = 0;
            expo_shift = 0; // where MSB located (from leftest)
            for (i=0; i<(F_MANT_W+1)*2; i=i+1) begin
                if (MSB_found_r == 1'b0 && i_data[(F_MANT_W+1)*2-1-i] == 1'b1) begin
                    MSB_found_r = 1'b1;
                    expo_shift = i;
                end
            end

            // expo_shift = (i_data[(F_MANT_W+1)*2-1] == 1'b1) ? 8'b1 : 8'b0;
            // G: LSB of result
            // R: 1st bit removed
            i_data = i_data << (expo_shift + 1);

            {BBG_r, round_r, remain_r} = i_data;
            guard_r = BBG_r[0];
            // S: OR of remaining
            sticky_r = (remain_r > 0);

            // round 2 even
            do_round = (round_r == 1 && sticky_r == 1) | // R = S = 1 
                        (round_r == 1 && guard_r == 1);  // G = R = 1

            // underflow: expo < 1, overflow: expo > 254
            // TODO: add one expo if round up to carry 
            fmul_unsigned_expo = {1'b0, f_nml_expo_a_w} + {1'b0, f_nml_expo_b_w} + (9'd1 - expo_shift);
            // is no MSB found, indicates 0
            // need to add one more expo after round up
            res_expo = (MSB_found_r) ? i_expo + (8'd1 - expo_shift) + (BBG_r == {F_MANT_W{1'b1}} & do_round) : 0;
            // underflow: < 1.0 * 2^-126
            o_invalid = (({1'b0, f_nml_expo_a_w} + {1'b0, f_nml_expo_b_w} + 9'd1 < expo_shift + 9'd128) & ~((res_expo == 0) & (BBG_r == 0)))      
                        | (fmul_unsigned_expo > 9'd381)
                        | ((fmul_unsigned_expo == 9'd381) & (BBG_r == {F_MANT_W{1'b1}}) & (round_r | sticky_r));      // overflow: > 1.11.1 * 2^127
            BBG_r = BBG_r + do_round;

            // pos 0 if ans is 0
            res_sign = (BBG_r == 0 && res_expo == 0) ? 0 : i_sign;

            MULround2NE = {o_invalid, 
                            res_sign, res_expo, BBG_r};

        end
    endfunction


endmodule