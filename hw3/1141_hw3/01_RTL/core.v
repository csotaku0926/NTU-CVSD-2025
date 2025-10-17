
module core (                       //Don't modify interface
	input      		i_clk,
	input      		i_rst_n,
	input    	  	i_in_valid,
	input 	[31: 0] i_in_data,

	output			o_in_ready,

	output	[ 7: 0]	o_out_data1,
	output	[ 7: 0]	o_out_data2,
	output	[ 7: 0]	o_out_data3,
	output	[ 7: 0]	o_out_data4,

	output	[11: 0] o_out_addr1,
	output	[11: 0] o_out_addr2,
	output	[11: 0] o_out_addr3,
	output	[11: 0] o_out_addr4,

	output 			o_out_valid1,
	output 			o_out_valid2,
	output 			o_out_valid3,
	output 			o_out_valid4,

	output 			o_exe_finish
);

// ================ parameters =====================
	localparam C128_01 		= 11'b11001101100; // 11001101100
	localparam C128_01_rev 		= 11'b00110110011;
	localparam C128_02 		= 11'b11001100110; // 11001100110
	localparam C128_02_rev 		= 11'b01100110011;
	localparam C128_03 		= 11'b10010011000; // 10010011000
	localparam C128_03_rev 		= 11'b00011001001;

	localparam C128_START 	= 11'b11010011100; // 11010011100
	localparam C128_START_rev 	= 11'b00111001011;
	localparam C128_END 	= 13'b11000_1110_1011; // 110001110_1011
	localparam C128_END_rev 	= 13'b1101_0111_00011;

	localparam IMG_SIZE = 4624; // 68 * 68
	localparam IMG_W = 64;

// ================ state machine ====================
	localparam S_IDLE = 3'd0;
	localparam S_INIMG = 3'd1;
	localparam S_OUTPARAM = 3'd2;
	localparam S_INWEIGHT = 3'd3;
	localparam S_OUTCONV = 3'd4;
	localparam S_END = 3'd5;

	reg [2:0]	state_r, state_next;

	wire        INIMG_end, INWEIGHT_end, OUTCONV_end;

	always @ (*) begin
		case (state_r) 
			S_IDLE: state_next = S_INIMG;
			S_INIMG: state_next = (INIMG_end) ? S_OUTPARAM : S_INIMG;
			S_OUTPARAM: state_next = S_INWEIGHT;
			S_INWEIGHT: state_next = (INWEIGHT_end) ? S_OUTCONV : S_INWEIGHT;
			S_OUTCONV: state_next = (OUTCONV_end) ? S_END : S_OUTCONV; // TODO: you need more than one cycle to output
			S_END: state_next = S_END;
		endcase
	end

    always @ (posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n)   state_r <= S_IDLE;
        else            state_r <= state_next;
    end

// ================ State 1: handling img input =================
	reg  	[7:0]	 img_r [0:IMG_SIZE-1]; // 64*64 img pixel including padding size max 2 --> 68 * 68
	reg  	[4095:0] img_lsb_r;
	reg     [12:0]	img_cnt_r;
	wire    [12:0]  img_idx;
// testing
	reg  			o_in_ready_r;
	integer 						i;

	assign o_in_ready = o_in_ready_r;
	assign INIMG_end = (img_cnt_r == 13'd4096) & (~i_in_valid);
	// index mapping: 2 * 68 + (i // 64) * 68 + 2 + (i % 64)
	assign img_idx = ((img_cnt_r >> 6) + 2) * (IMG_W + 4) + 2 + (img_cnt_r & 5'b11111);

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			o_in_ready_r <= 0;
			// img
			img_cnt_r <= 0;
			for (i=0; i<IMG_SIZE; i=i+1) begin 
				img_r[i] <= 8'b0;
				img_lsb_r[i] <= 0;
			end
		end

		else begin
			o_in_ready_r <= 1;

			if ((state_next == S_INIMG) && i_in_valid) begin
				// read 4-byte a time
				{ img_r[img_idx], img_r[img_idx + 1], img_r[img_idx + 2], img_r[img_idx + 3] } <= i_in_data;
				img_lsb_r[img_cnt_r] 	<= i_in_data[24];
				img_lsb_r[img_cnt_r + 1] <= i_in_data[16];
				img_lsb_r[img_cnt_r + 2] <= i_in_data[8];
				img_lsb_r[img_cnt_r + 3] <= i_in_data[0];
				img_cnt_r <= img_cnt_r + 4;
			end
			else begin
				img_cnt_r <= (state_r == S_INIMG) ? img_cnt_r : 0;
			end

		end
	end

// ================== Output Valid Signal =============
	reg		[ 7: 0]	kernel_sz_r;
	reg		[ 7: 0]	stride_sz_r;
	reg		[ 7: 0]	dilation_sz_r;

	reg		[ 7: 0]	o_out_data1_r;
	reg		[ 7: 0]	o_out_data2_r;
	reg		[ 7: 0]	o_out_data3_r;
	reg		[ 7: 0]	o_out_data4_r;

	reg		[11: 0] o_out_addr1_r;
	reg		[11: 0] o_out_addr2_r;
	reg		[11: 0] o_out_addr3_r;
	reg		[11: 0] o_out_addr4_r;

	reg 			o_out_valid1_r;
	reg 			o_out_valid2_r;
	reg 			o_out_valid3_r;
	reg 			o_out_valid4_r;

	wire  			isInvalid; // invalid config

// output valid signals
	assign o_out_valid1 = o_out_valid1_r;
	assign o_out_valid2 = o_out_valid2_r;
	assign o_out_valid3 = o_out_valid3_r;
	assign o_out_valid4 = o_out_valid4_r;

	assign isInvalid = (state_r == S_OUTPARAM) & (o_out_data1 == 0) & (o_out_data2 == 0) & (o_out_data3 == 0);

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			o_out_valid1_r <= 0;
			o_out_valid2_r <= 0;
			o_out_valid3_r <= 0;
			o_out_valid4_r <= 0;
		end
		else begin
			o_out_valid1_r <= (state_next == S_OUTPARAM) | (state_next == S_OUTCONV);
			o_out_valid2_r <= (state_next == S_OUTPARAM) | (state_next == S_OUTCONV);
			o_out_valid3_r <= (state_next == S_OUTPARAM) | (state_next == S_OUTCONV);
			o_out_valid4_r <= (state_next == S_OUTCONV); 
		end
	end

// output data
	assign o_out_data1 = o_out_data1_r;
	assign o_out_data2 = o_out_data2_r;
	assign o_out_data3 = o_out_data3_r;
	assign o_out_data4 = o_out_data4_r;

	// output addr (for conv)
	assign o_out_addr1 = o_out_addr1_r;
	assign o_out_addr2 = o_out_addr2_r;
	assign o_out_addr3 = o_out_addr3_r;
	assign o_out_addr4 = o_out_addr4_r;

	// return { isvalid, kernel size, stride size, dilation size }
	// (TODO: of course, this is slow as hell, requires pipeline)
	function automatic [23:0] get128C;
		input [4095:0] img_lsb_r;	
		reg   [11:0] mask;
		reg   [13:0] mask13;
		reg   [11-1:0] out1_code_r, out2_code_r, out3_code_r;
		reg   [8-1:0]		out1_r, out2_r, out3_r;
		reg   			C128_found;
		integer i;

		begin
			mask = (1 << 11) - 1;
			mask13 = (1 << 13) - 1;
			C128_found = 0;
			out1_r = 0;
			out2_r = 0;
			out3_r = 0;

			for (i=0; i<3476; i=i+1) begin // 4096-620
				// found the start code! (height should be 10)
				if ( 
					(((img_lsb_r >> i) & mask) == C128_START_rev) && (((img_lsb_r >> (i + 44)) & mask13) == C128_END_rev) &&
					(((img_lsb_r >> (i + 576)) & mask) == C128_START_rev) && (((img_lsb_r >> (i + 620)) & mask13) == C128_END_rev)
				) begin // [11+i:i]
					C128_found = 1;
					out1_code_r = (img_lsb_r >> (i+11)) & mask;
					out2_code_r = (img_lsb_r >> (i+22)) & mask;
					out3_code_r = (img_lsb_r >> (i+33)) & mask;
					
					out1_r = 	(out1_code_r == C128_03_rev) ? 8'd3 : 0; // kernel size can only be 3
					out2_r = 	(out2_code_r == C128_01_rev) ? 8'd1 : (
								(out2_code_r == C128_02_rev ? 8'd2 : 0)); // stride can be 1 or 2

					out3_r = 	(out3_code_r == C128_01_rev) ? 8'd1 : (
								(out3_code_r == C128_02_rev ? 8'd2 : 0)); // dilation can be 1 or 2
				end 		
			end

			// only output data if valid
			get128C = (out1_r > 0 && out2_r > 0 && out3_r > 0) ? { out1_r, out2_r, out3_r } : 23'b0 ;
		end
	endfunction

// =============== State 3: handle weight input ==============
	reg     [7:0]	weight_r [0:11]; // 3x3 8-bit signed fixed point weight
	reg  	[4:0]	weight_cnt_r; // for 3 cycles

	assign INWEIGHT_end = (weight_cnt_r == 4'd12);

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			weight_cnt_r <= 0;
			for (i=0; i<9; i=i+1) weight_r[i] <= 8'b0;
		end
		else if ((state_next == S_INWEIGHT) && i_in_valid) begin
			// read 4 8-bit weight
			{ weight_r[weight_cnt_r], weight_r[weight_cnt_r + 1], weight_r[weight_cnt_r + 2], weight_r[weight_cnt_r + 3]} <= i_in_data;
			weight_cnt_r <= weight_cnt_r + 4;
		end
	end

// =============== State 2: find target 128-C barcode & output param && State 4: output convolution ==================================
	reg   	[12:0]		conv_cnt_r;
	wire  	[12:0]		conv_idx_w; 
	wire  	[71:0]		conv_in0_img_w, conv_in1_img_w, conv_in2_img_w, conv_in3_img_w;
	wire    [71:0]		conv_in_weight_w;

	assign conv_in_weight_w = weight_r[0:8];
	// index mapping: 2 * 68 + (i // 64) * 68 + 2 + (i % 64)
	assign conv_idx_w = ((conv_cnt_r >> 6) + 2) * (IMG_W + 4) + 2 + (conv_cnt_r & 5'b11111);
	// j+(-68-1)*D, j-68*D,
	// j-D, j, j+D
	assign conv_in0_img_w = {
		img_r[conv_idx_w - 69 * dilation_sz_r], img_r[conv_idx_w - 68 * dilation_sz_r], img_r[conv_idx_w - 67 * dilation_sz_r],
		img_r[conv_idx_w -  1 * dilation_sz_r], img_r[conv_idx_w], 						img_r[conv_idx_w + 1 * dilation_sz_r],
		img_r[conv_idx_w + 67 * dilation_sz_r], img_r[conv_idx_w + 68 * dilation_sz_r], img_r[conv_idx_w + 69 * dilation_sz_r],
	};
	assign conv_in1_img_w = {
		img_r[conv_idx_w + 1 * stride_sz_r - 69 * dilation_sz_r], img_r[conv_idx_w + 1 * stride_sz_r - 68 * dilation_sz_r], img_r[conv_idx_w + 1 * stride_sz_r - 67 * dilation_sz_r],
		img_r[conv_idx_w + 1 * stride_sz_r -  1 * dilation_sz_r], img_r[conv_idx_w + 1 * stride_sz_r], 						img_r[conv_idx_w + 1 * stride_sz_r + 1 * dilation_sz_r],
		img_r[conv_idx_w + 1 * stride_sz_r + 67 * dilation_sz_r], img_r[conv_idx_w + 1 * stride_sz_r + 68 * dilation_sz_r], img_r[conv_idx_w + 1 * stride_sz_r + 69 * dilation_sz_r],
	};

	assign conv_in2_img_w = {
		img_r[conv_idx_w + 2 * stride_sz_r - 69 * dilation_sz_r], img_r[conv_idx_w + 2 * stride_sz_r - 68 * dilation_sz_r], img_r[conv_idx_w + 2 * stride_sz_r - 67 * dilation_sz_r],
		img_r[conv_idx_w + 2 * stride_sz_r -  1 * dilation_sz_r], img_r[conv_idx_w + 2 * stride_sz_r], 						img_r[conv_idx_w + 2 * stride_sz_r + 1 * dilation_sz_r],
		img_r[conv_idx_w + 2 * stride_sz_r + 67 * dilation_sz_r], img_r[conv_idx_w + 2 * stride_sz_r + 68 * dilation_sz_r], img_r[conv_idx_w + 2 * stride_sz_r + 69 * dilation_sz_r],
	};

	assign conv_in3_img_w = {
		img_r[conv_idx_w + 3 * stride_sz_r - 69 * dilation_sz_r], img_r[conv_idx_w + 3 * stride_sz_r - 68 * dilation_sz_r], img_r[conv_idx_w + 3 * stride_sz_r - 67 * dilation_sz_r],
		img_r[conv_idx_w + 3 * stride_sz_r -  1 * dilation_sz_r], img_r[conv_idx_w + 3 * stride_sz_r], 						img_r[conv_idx_w + 3 * stride_sz_r + 1 * dilation_sz_r],
		img_r[conv_idx_w + 3 * stride_sz_r + 67 * dilation_sz_r], img_r[conv_idx_w + 3 * stride_sz_r + 68 * dilation_sz_r], img_r[conv_idx_w + 3 * stride_sz_r + 69 * dilation_sz_r],
	};
	
	assign OUTCONV_end = (stride_sz_r == 1) ? (conv_cnt_r >= 32) : (conv_cnt_r >= 64);

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			kernel_sz_r <= 0;
			stride_sz_r <= 0;
			dilation_sz_r <= 0;

			o_out_data1_r <= 0;
			o_out_data2_r <= 0;
			o_out_data3_r <= 0;
			o_out_data4_r <= 0;

			o_out_addr1_r <= 0;
			o_out_addr2_r <= 0;
			o_out_addr3_r <= 0;
			o_out_addr4_r <= 0;

			conv_cnt_r <= 0;
		end
		else if (state_next == S_OUTPARAM) begin
			{ kernel_sz_r, stride_sz_r, dilation_sz_r } <= get128C(img_lsb_r); // store parameters for convolution
			{ o_out_data1_r, o_out_data2_r, o_out_data3_r } <= get128C(img_lsb_r);
			o_out_data4_r <= 0;
		end
		else if (state_next == S_OUTCONV) begin
			// output size: 64 x 64 if stride = 1; 32 x 32 if 2
			// output 4-byte at once
			o_out_data1_r <= conv1byte(conv_in0_img_w, conv_in_weight_w);
			o_out_data2_r <= conv1byte(conv_in1_img_w, conv_in_weight_w);
			o_out_data3_r <= conv1byte(conv_in2_img_w, conv_in_weight_w);
			o_out_data4_r <= conv1byte(conv_in3_img_w, conv_in_weight_w);
			conv_cnt_r <= conv_cnt_r + (stride_sz_r << 2); // 4 * stride
		end
	end

	// output for a single 3x3 convolution
	function automatic [ 7: 0] conv1byte;
		input [ 71: 0] 		i_img; // 9 8-bit input
		input [ 71: 0]		i_weight;

		reg [7:0]			img_i_r, weight_i_r, us_weight_i_r;
		reg [20:0]				tmp_r, sum_r; // 8*2+log(9) = 20
		reg  				do_round;
		integer i;

		begin
			tmp_r = 0;
			sum_r = 0;
			for (i=0; i<9 i=i+1) begin // K=3 in this assignment
				img_i_r = (i_img >> (8 * i)) & 8'b1111_1111;
				weight_i_r = (i_weight >> (8 * i)) & 8'b1111_1111;
				tmp_r = $signed({4'b0, img_i_r, 8'b0}) * $signed({ {12{weight_i_r[7]}}, weight_i_r});
				sum_r = sum_r + tmp_r;
			end

			// round to nearest
			do_round = (~sum[20] & sum_r[7]) | (sum[20] & ~sum[7] & (sum[7:0] > 0));
			sum_r = (do_round) ? sum_r + 21'b01_0000_0000 : sum_r;

			// clamp to [0, 255] ([20]: signed, [15:8] --> integer, [7:0] --> fraction)
			conv1byte = (sum_r[20] == 1) ? 0 : ( // negative
					(sum_r[19:16] > 0) ? 8'd255 : // overflow 255
					sum_r[15:8]
			);
		end 
	endfunction

// =============== State 5: terminate ==============
	reg 			o_exe_finish_r;

	assign o_exe_finish = o_exe_finish_r;
	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) 	o_exe_finish_r <= 0;
		else  			o_exe_finish_r <= isInvalid | (state_next == S_END);
	end


endmodule
