
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
	// localparam C128_01_rev 		= 11'b00110110011;
	localparam C128_02 		= 11'b11001100110; // 11001100110
	// localparam C128_02_rev 		= 11'b01100110011;
	localparam C128_03 		= 11'b10010011000; // 10010011000
	// localparam C128_03_rev 		= 11'b00011001001;

	localparam C128_START 	= 11'b11010011100; // 11010011100
	// localparam C128_START_rev 	= 11'b00111001011;
	localparam C128_END 	= 13'b11000_1110_1011; // 110001110_1011
	// localparam C128_END_rev 	= 13'b1101_0111_00011;

	// localparam IMG_SIZE = 4624; // 68 * 68
	localparam LSB_SIZE = 636; // 64*9 + 57 = 633 --> make it 4 divisible
	localparam MULT_SIZE = 27; // multiplication size
	localparam RES_SIZE = 27; // buffering conv result
	// localparam IMG_W = 64;

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
			S_OUTCONV: state_next = (OUTCONV_end) ? S_END : S_OUTCONV; 
			S_END: state_next = S_END;
			default: state_next = S_IDLE;
		endcase
	end

    always @ (posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n)   state_r <= S_IDLE;
        else            state_r <= state_next;
    end

// ================ State 1: handling img input =================
	// reg  	[7:0]	 img_r [0:IMG_SIZE-1]; // 64*64 img pixel including padding size max 2 --> 68 * 68
	// reg  	[4095:0] img_lsb_r;
	reg  	[LSB_SIZE-1:0]	lsb_buf_r; 
	reg     [12:0]	img_cnt_r;
	// wire    [12:0]  img_idx;
	
	reg  			o_in_ready_r;
	integer 						i;

	assign o_in_ready = o_in_ready_r;
	assign INIMG_end = (img_cnt_r == 13'd4096) & (~i_in_valid);
	// index mapping: 2 * 68 + (i // 64) * 68 + 2 + (i % 64)
	// assign img_idx = ((img_cnt_r >> 6) + 2) * (IMG_W + 4) + 2 + (img_cnt_r & 6'b111111);

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			o_in_ready_r <= 0;
			img_cnt_r <= 0;
			for (i=0; i<LSB_SIZE; i=i+1) lsb_buf_r[i] <= 0; 
			// for (i=0; i<4096; i=i+1) img_lsb_r[i] <= 0;
		end

		else begin
			o_in_ready_r <= 1;

			if ((state_next == S_INIMG) && i_in_valid) begin
				// img_lsb_r[img_cnt_r] 	<= i_in_data[24];
				// img_lsb_r[img_cnt_r + 1] <= i_in_data[16];
				// img_lsb_r[img_cnt_r + 2] <= i_in_data[8];
				// img_lsb_r[img_cnt_r + 3] <= i_in_data[0];
				
				// read LSB
				lsb_buf_r <= {lsb_buf_r[LSB_SIZE-5:0], i_in_data[24], i_in_data[16], i_in_data[8], i_in_data[0]};
				// read 4-byte a time
				img_cnt_r <= img_cnt_r + 4;
			end
			else begin
				img_cnt_r <= (state_r == S_INIMG) ? img_cnt_r : 0;
			end

		end
	end

// find conv parameter with pipeline
	wire  	[LSB_SIZE-1:0]	lsb_buf_w; 
	reg		[ 7: 0]	kernel_sz_r;
	reg		[ 7: 0]	stride_sz_r;
	reg		[ 7: 0]	dilation_sz_r;
	wire 	[23:0] 	res1_w, res2_w, res3_w, res4_w;

	assign lsb_buf_w = {lsb_buf_r[LSB_SIZE-5:0], i_in_data[24], i_in_data[16], i_in_data[8], i_in_data[0]};

	assign res1_w = get128C_pp(lsb_buf_w, 0);
	assign res2_w = get128C_pp(lsb_buf_w, 1);
	assign res3_w = get128C_pp(lsb_buf_w, 2);
	assign res4_w = get128C_pp(lsb_buf_w, 3);

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			kernel_sz_r <= 0;
			stride_sz_r <= 0;
			dilation_sz_r <= 0;
		end
		else if ((state_next == S_INIMG) && i_in_valid) begin

			if (kernel_sz_r == 0)
				kernel_sz_r <= (res1_w[23:16] | res2_w[23:16] | res3_w[23:16] | res4_w[23:16]);
			if (stride_sz_r == 0)
				stride_sz_r <= (res1_w[15:8] | res2_w[15:8] | res3_w[15:8] | res4_w[15:8]);
			if (dilation_sz_r == 0)
				dilation_sz_r <= (res1_w[7:0] | res2_w[7:0] | res3_w[7:0] | res4_w[7:0]); 
		end
	end

	function automatic [23:0] get128C_pp;
		input [LSB_SIZE-1:0] lsb_buf_r;
		input [1:0]			i_offset;
		reg  [7:0] Kw, Sw, Dw;

		begin
			Kw = 0;
			Sw = 0;
			Dw = 0;
			if (
				(lsb_buf_r[LSB_SIZE-1-i_offset -:11 ] == C128_START) & (lsb_buf_r[LSB_SIZE-45-i_offset -:13] == C128_END)
				& (lsb_buf_r[LSB_SIZE-65-i_offset -:11] == C128_START) & (lsb_buf_r[LSB_SIZE-109-i_offset -:13] == C128_END)
				& (lsb_buf_r[LSB_SIZE-129-i_offset -:11] == C128_START) & (lsb_buf_r[LSB_SIZE-173-i_offset -:13] == C128_END)
				& (lsb_buf_r[LSB_SIZE-193-i_offset -:11] == C128_START) & (lsb_buf_r[LSB_SIZE-237-i_offset -:13] == C128_END)
				& (lsb_buf_r[LSB_SIZE-257-i_offset -:11] == C128_START) & (lsb_buf_r[LSB_SIZE-301-i_offset -:13] == C128_END)
				& (lsb_buf_r[LSB_SIZE-321-i_offset -:11] == C128_START) & (lsb_buf_r[LSB_SIZE-365-i_offset -:13] == C128_END)
				& (lsb_buf_r[LSB_SIZE-385-i_offset -:11] == C128_START) & (lsb_buf_r[LSB_SIZE-429-i_offset -:13] == C128_END)
				& (lsb_buf_r[LSB_SIZE-449-i_offset -:11] == C128_START) & (lsb_buf_r[LSB_SIZE-493-i_offset -:13] == C128_END)
				& (lsb_buf_r[LSB_SIZE-513-i_offset -:11] == C128_START) & (lsb_buf_r[LSB_SIZE-557-i_offset -:13] == C128_END)
				& (lsb_buf_r[LSB_SIZE-577-i_offset -:11] == C128_START) & (lsb_buf_r[LSB_SIZE-621-i_offset -:13] == C128_END)
			) begin
				Kw = (lsb_buf_r[LSB_SIZE-12-i_offset -:11] == C128_03) ? 3 : 0;
				Sw = (lsb_buf_r[LSB_SIZE-23-i_offset -:11] == C128_01) ? 1 : (
					(lsb_buf_r[LSB_SIZE-23-i_offset -:11] == C128_02) ? 2 : 0
				);
				Dw = (lsb_buf_r[LSB_SIZE-34-i_offset -:11] == C128_01) ? 1 : (
					(lsb_buf_r[LSB_SIZE-34-i_offset -:11] == C128_02) ? 2 : 0
				);

			end
			get128C_pp = ((Kw > 0) & (Sw > 0) & (Dw > 0)) ? {Kw, Sw, Dw} : 24'b0;
		end
	endfunction


// ================== SRAM module =====================
	// wire 			sram00_in_CEN, sram01_in_CEN, sram02_in_CEN, sram03_in_CEN; 
	// wire			sram04_in_CEN, sram05_in_CEN, sram06_in_CEN, sram07_in_CEN;
	// wire 			sram20_in_CEN, sram21_in_CEN, sram22_in_CEN, sram23_in_CEN;
	// wire 			sram30_in_CEN, sram31_in_CEN, sram32_in_CEN, sram33_in_CEN;
	wire  			sram_r0_in_CEN, sram_r1_in_CEN; //, sram_r2_in_CEN, sram_r3_in_CEN;

	// wire  			sram00_in_WEN, sram01_in_WEN, sram02_in_WEN, sram03_in_WEN;
	// wire  			sram04_in_WEN, sram05_in_WEN, sram06_in_WEN, sram07_in_WEN;
	// wire  			sram20_in_WEN, sram21_in_WEN, sram22_in_WEN, sram23_in_WEN;
	// wire  			sram30_in_WEN, sram31_in_WEN, sram32_in_WEN, sram33_in_WEN;
	wire  			sram_in_WEN;
	wire  			start_load_sram_w; // start reading from the cycle before "s_next == S_OUTCONV"

	reg 	[8:0]	sram00_in_addr, sram01_in_addr, sram02_in_addr, sram03_in_addr;
	reg 	[8:0]	sram04_in_addr, sram05_in_addr, sram06_in_addr, sram07_in_addr;	
	// for out conv
	wire 	[8:0]	sram00_load_addr, sram01_load_addr, sram02_load_addr, sram03_load_addr;
	wire 	[8:0]	sram04_load_addr, sram05_load_addr, sram06_load_addr, sram07_load_addr;	

	reg		[7:0]	sram00_in_data, sram01_in_data, sram02_in_data, sram03_in_data; 
	reg 	[7:0] 	sram04_in_data, sram05_in_data, sram06_in_data, sram07_in_data; 
	// reg 	[7:0]	sram20_in_data, sram21_in_data, sram22_in_data, sram23_in_data; 
	// reg 	[7:0]	sram30_in_data, sram31_in_data, sram32_in_data, sram33_in_data;

	wire	[7:0]	sram00_out_data, sram01_out_data, sram02_out_data, sram03_out_data; 
	wire 	[7:0]	sram04_out_data, sram05_out_data, sram06_out_data, sram07_out_data;  
	// wire 	[7:0]	sram20_out_data, sram21_out_data, sram22_out_data, sram23_out_data; 
	// wire 	[7:0]	sram30_out_data, sram31_out_data, sram32_out_data, sram33_out_data;

	// note need to enable for one more cycle to write last data in
	assign sram_in_WEN = ~((state_r == S_INIMG) | state_next == S_OUTPARAM);

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			sram00_in_addr <= 0;
			sram01_in_addr <= 0;
			sram02_in_addr <= 0;
			sram03_in_addr <= 0;
			sram04_in_addr <= 0;
			sram05_in_addr <= 0;
			sram06_in_addr <= 0;
			sram07_in_addr <= 0;
		end
		// 00 01 02 03 10 11 12 13
		else if (state_r == S_INIMG) begin
			sram00_in_addr <= (img_cnt_r >> 3);
			sram01_in_addr <= (img_cnt_r >> 3);
			sram02_in_addr <= (img_cnt_r >> 3);
			sram03_in_addr <= (img_cnt_r >> 3);
			sram04_in_addr <= (img_cnt_r >> 3);
			sram05_in_addr <= (img_cnt_r >> 3);
			sram06_in_addr <= (img_cnt_r >> 3);
			sram07_in_addr <= (img_cnt_r >> 3);
		end
		else if (start_load_sram_w | (state_next == S_OUTCONV) ) begin
			sram00_in_addr <= sram00_load_addr;
			sram01_in_addr <= sram01_load_addr;
			sram02_in_addr <= sram02_load_addr;
			sram03_in_addr <= sram03_load_addr;
			sram04_in_addr <= sram04_load_addr;
			sram05_in_addr <= sram05_load_addr;
			sram06_in_addr <= sram06_load_addr;
			sram07_in_addr <= sram07_load_addr;
		end
	end

// module instantiate
	sram_512x8 u_sram00(
		.A(sram00_in_addr), // address
		.CEN(sram_r0_in_CEN), // chip enable: 1 means enable, 0 is disable
		.WEN(sram_in_WEN), // write enable: 1 writes, 0 reads
		.D(sram00_in_data), // data input
		.CLK(i_clk),
		.Q(sram00_out_data) // data output
	);
	sram_512x8 u_sram01(
		.A(sram01_in_addr), // address
		.CEN(sram_r0_in_CEN), // chip enable: 1 means enable, 0 is disable
		.WEN(sram_in_WEN), // write enable: 1 writes, 0 reads
		.D(sram01_in_data), // data input
		.CLK(i_clk),
		.Q(sram01_out_data) // data output
	);
	sram_512x8 u_sram02(
		.A(sram02_in_addr), // address
		.CEN(sram_r0_in_CEN), // chip enable: 1 means enable, 0 is disable
		.WEN(sram_in_WEN), // write enable: 1 writes, 0 reads
		.D(sram02_in_data), // data input
		.CLK(i_clk),
		.Q(sram02_out_data) // data output
	);
	sram_512x8 u_sram03(
		.A(sram03_in_addr), // address
		.CEN(sram_r0_in_CEN), // chip enable: 1 means enable, 0 is disable
		.WEN(sram_in_WEN), // write enable: 1 writes, 0 reads
		.D(sram03_in_data), // data input
		.CLK(i_clk),
		.Q(sram03_out_data) // data output
	);
	sram_512x8 u_sram04(
		.A(sram04_in_addr), // address
		.CEN(sram_r1_in_CEN), // chip enable: 1 means enable, 0 is disable
		.WEN(sram_in_WEN), // write enable: 1 writes, 0 reads
		.D(sram04_in_data), // data input
		.CLK(i_clk),
		.Q(sram04_out_data) // data output
	);
	sram_512x8 u_sram05(
		.A(sram05_in_addr), // address
		.CEN(sram_r1_in_CEN), // chip enable: 1 means enable, 0 is disable
		.WEN(sram_in_WEN), // write enable: 1 writes, 0 reads
		.D(sram05_in_data), // data input
		.CLK(i_clk),
		.Q(sram05_out_data) // data output
	);
	sram_512x8 u_sram06(
		.A(sram06_in_addr), // address
		.CEN(sram_r1_in_CEN), // chip enable: 1 means enable, 0 is disable
		.WEN(sram_in_WEN), // write enable: 1 writes, 0 reads
		.D(sram06_in_data), // data input
		.CLK(i_clk),
		.Q(sram06_out_data) // data output
	);
	sram_512x8 u_sram07(
		.A(sram07_in_addr), // address
		.CEN(sram_r1_in_CEN), // chip enable: 1 means enable, 0 is disable
		.WEN(sram_in_WEN), // write enable: 1 writes, 0 reads
		.D(sram07_in_data), // data input
		.CLK(i_clk),
		.Q(sram07_out_data) // data output
	);

//  handle image input 
	wire  [12:0] sram_write_sel;

	assign sram_write_sel = img_cnt_r & 3'b111;
	assign sram_r0_in_CEN = 1'b0; //((sram_write_sel < 4) && ((state_r == S_INIMG) && i_in_valid)) | (state_r != S_INIMG);
	assign sram_r1_in_CEN = 1'b0; //((4 <= sram_write_sel) && ((state_r == S_INIMG) && i_in_valid)) | (state_r != S_INIMG);
	// assign sram_r2_in_CEN = (8'd64 <= sram_write_sel) && (sram_write_sel < 8'd128) && ((state_next == S_INIMG) && i_in_valid);
	// assign sram_r3_in_CEN = (8'd128 <= sram_write_sel) && (sram_write_sel < 8'd192) && ((state_next == S_INIMG) && i_in_valid);

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			sram00_in_data <= 0;
			sram01_in_data <= 0;
			sram02_in_data <= 0;
			sram03_in_data <= 0;

			sram04_in_data <= 0;
			sram05_in_data <= 0;
			sram06_in_data <= 0;
			sram07_in_data <= 0;
			
		end
		else if ((state_r == S_INIMG) && i_in_valid) begin
			if (sram_write_sel < 4) // img_cnt_r % 256
				{ sram00_in_data, sram01_in_data, sram02_in_data, sram03_in_data } <= i_in_data;
			else 
				{ sram04_in_data, sram05_in_data, sram06_in_data, sram07_in_data } <= i_in_data;
		end
	end

// ================== Output Valid & Data Signal =============
	// reg		[ 7: 0]	kernel_sz_r;
	// reg		[ 7: 0]	stride_sz_r;
	// reg		[ 7: 0]	dilation_sz_r;

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
	wire  			convReady;
	wire  			s2_odd_valid, s2_even_valid; // for conv stride = 2

	reg  [RES_SIZE-1:0]	conv_out_data1_r, conv_out_data2_r, conv_out_data3_r, conv_out_data4_r; // for conv output

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
			o_out_valid1_r <= (state_next == S_OUTPARAM) | ((state_next == S_OUTCONV) & convReady & s2_odd_valid);
			o_out_valid2_r <= (state_next == S_OUTPARAM) | ((state_next == S_OUTCONV) & convReady & s2_even_valid);
			o_out_valid3_r <= (state_next == S_OUTPARAM) | ((state_next == S_OUTCONV) & convReady & s2_odd_valid);
			o_out_valid4_r <= ((state_next == S_OUTCONV) & convReady & s2_even_valid); 
		end
	end

	// output data
	assign o_out_data1 = (state_r == S_OUTCONV) ? round2_8bit(conv_out_data1_r) : o_out_data1_r;
	assign o_out_data2 = (state_r == S_OUTCONV) ? round2_8bit(conv_out_data2_r) : o_out_data2_r;
	assign o_out_data3 = (state_r == S_OUTCONV) ? round2_8bit(conv_out_data3_r) : o_out_data3_r;
	assign o_out_data4 = (state_r == S_OUTCONV) ? round2_8bit(conv_out_data4_r) : o_out_data4_r;

	// output addr (for conv)
	assign o_out_addr1 = o_out_addr1_r;
	assign o_out_addr2 = o_out_addr2_r;
	assign o_out_addr3 = o_out_addr3_r;
	assign o_out_addr4 = o_out_addr4_r;

// get128C : return { isvalid, kernel size, stride size, dilation size }
	// (TODO: of course, this is slow as hell, requires pipeline)
	// function automatic [23:0] get128C;
	// 	input [4095:0] img_lsb_r;	
	// 	reg   [11:0] mask;
	// 	reg   [13:0] mask13;
	// 	reg   [11-1:0] out1_code_r, out2_code_r, out3_code_r;
	// 	reg   [8-1:0]		out1_r, out2_r, out3_r;
	// 	reg   			C128_found;
	// 	integer i;

	// 	begin
	// 		mask = (1 << 11) - 1;
	// 		mask13 = (1 << 13) - 1;
	// 		C128_found = 0;
	// 		out1_r = 0;
	// 		out2_r = 0;
	// 		out3_r = 0;

	// 		for (i=0; i<3476; i=i+1) begin // 4096-620
	// 			// found the start code! (height should be 10)
	// 			if ( 
	// 				(((img_lsb_r >> i) & mask) == C128_START_rev) && (((img_lsb_r >> (i + 44)) & mask13) == C128_END_rev) &&
	// 				(((img_lsb_r >> (i + 576)) & mask) == C128_START_rev) && (((img_lsb_r >> (i + 620)) & mask13) == C128_END_rev)
	// 			) begin // [11+i:i]
	// 				C128_found = 1;
	// 				out1_code_r = (img_lsb_r >> (i+11)) & mask;
	// 				out2_code_r = (img_lsb_r >> (i+22)) & mask;
	// 				out3_code_r = (img_lsb_r >> (i+33)) & mask;
					
	// 				out1_r = 	(out1_code_r == C128_03_rev) ? 8'd3 : 0; // kernel size can only be 3
	// 				out2_r = 	(out2_code_r == C128_01_rev) ? 8'd1 : (
	// 							(out2_code_r == C128_02_rev ? 8'd2 : 0)); // stride can be 1 or 2

	// 				out3_r = 	(out3_code_r == C128_01_rev) ? 8'd1 : (
	// 							(out3_code_r == C128_02_rev ? 8'd2 : 0)); // dilation can be 1 or 2
	// 			end 		
	// 		end

	// 		// only output data if valid
	// 		get128C = (out1_r > 0 && out2_r > 0 && out3_r > 0) ? { out1_r, out2_r, out3_r } : 23'b0 ;
	// 	end
	// endfunction

// =============== State 3: handle weight input ==============
	reg     [7:0]	weight_r [0:11]; // 3x3 8-bit signed fixed point weight
	reg  	[4:0]	weight_cnt_r; // for 3 cycles

	assign INWEIGHT_end = (weight_cnt_r == 4'd12);
	assign start_load_sram_w = (state_r == S_INWEIGHT); //(weight_cnt_r >= 4);

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

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			o_out_data1_r <= 0;
			o_out_data2_r <= 0;
			o_out_data3_r <= 0;
			o_out_data4_r <= 0;

		end
		else if (state_next == S_OUTPARAM) begin
			// { kernel_sz_r, stride_sz_r, dilation_sz_r } <= get128C(img_lsb_r); // store parameters for convolution
			// { o_out_data1_r, o_out_data2_r, o_out_data3_r } <= get128C(img_lsb_r);
			o_out_data1_r <= kernel_sz_r;
			o_out_data2_r <= stride_sz_r;
			o_out_data3_r <= dilation_sz_r;
			o_out_data4_r <= 0;
		end
	end

//  ================ State 4 : convolution pipeline (valid outputs start from iter = 1) =============================
	// wire  	[12:0]  idx_w;
	reg     [11:0]	pp_iter_r; 
	wire  	[8:0]	row_w, col_w; // valid: 0~63
	wire  	[11:0]	pp_iter_r_m1;
	wire  	[8:0]	row2_w, col2_w; // valid: 0~63
	wire  	[11:0]	pp_iter_r_m2;
	// reg  	[1:0] 	pp_cnt_r;

	assign OUTCONV_end = (pp_iter_r > 12'd1025);//(stride_sz_r == 1) ? (pp_iter_r > 13'd1024) : (conv_i_r >= 1024);
	// start the first valid output
	assign convReady = (pp_iter_r > 1) & (state_r == S_OUTCONV);

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			// pp_cnt_r <= 0;
			pp_iter_r <= 0;
		end
		else if (state_next == S_OUTCONV) begin
			// pp_cnt_r <= (pp_cnt_r == 2'd2) ? 0 : pp_cnt_r + 1; // 0, 1, 2, 0..
			pp_iter_r <= pp_iter_r + 1;
		end
	end


	reg   [10:0] load_i_r;
	wire  [8:0]	load_row_w, load_col_w;
	wire  [12:0] load_idx_w;
// load SRAM  
	// ((i % 32) / 2) + ((i & 64) > 32)
	// dilation = 2: 0 -> 2 .. -> 62 -> 1 .. -> 63 -> 0
	assign load_row_w = (dilation_sz_r == 1) ? (load_i_r & 6'b11_1111) : 
												((load_i_r & 5'b1_1111) << 1) + (load_i_r[5]); 
	assign load_col_w = (load_i_r >> 6) << 2;
	assign load_idx_w = (load_row_w << 6) + load_col_w; // 0 --> 64 --> 128

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) load_i_r <= 0;
		else if (start_load_sram_w | (state_next == S_OUTCONV)) load_i_r <= load_i_r + 1;
	end

	// 06  07 | (00) (01) (02) (03) 04  05 06 07 | 00 01 
	assign sram00_load_addr = (load_idx_w >> 3) + load_i_r[6]; //((load_i_r & 7'b111_1111) >= 64); 
	assign sram01_load_addr = (load_idx_w >> 3) + load_i_r[6]; // + ((load_i_r & 7'b111_1111) >= 64);
	assign sram02_load_addr = (load_idx_w >> 3);
	assign sram03_load_addr = (load_idx_w >> 3);
	assign sram04_load_addr = (load_idx_w >> 3);
	assign sram05_load_addr = (load_idx_w >> 3);
	assign sram06_load_addr = (load_idx_w >> 3) - (1'b1 - load_i_r[6]); //((load_i_r & 7'b111_1111) < 64);
	assign sram07_load_addr = (load_idx_w >> 3) - (1'b1 - load_i_r[6]); //((load_i_r & 7'b111_1111) < 64);

// pipeline process
	// img pixel for each conv iteration
	wire  	[7:0]	img_00_w, img_01_w, img_02_w, img_03_w;
	wire 	[7:0] 	img_04_w, img_05_w, img_06_w, img_07_w;
	wire 			switch_conv_w;


	// pp = 2 --> (0, 0); 64 --> (0, 4)
	// (P-1) % 64, (P-1) / 64)
	assign pp_iter_r_m1 = pp_iter_r - 1;
	assign row_w = (state_r == S_OUTCONV) ? (
		(dilation_sz_r == 1) ? pp_iter_r_m1 & 6'b11_1111 : ((pp_iter_r_m1 & 5'b1_1111) << 1) + (pp_iter_r_m1[5])
		) : 0; 
	assign col_w = (state_r == S_OUTCONV) ? (pp_iter_r_m1 >> 6) << 2 : 0;

	// for output address
	assign pp_iter_r_m2 = pp_iter_r - 2;
	assign row2_w = (state_r == S_OUTCONV) ? (
		(dilation_sz_r == 1) ? pp_iter_r_m2 & 6'b11_1111 : ((pp_iter_r_m2 & 5'b1_1111) << 1) + (pp_iter_r_m2[5])
		) : 0; 
	assign col2_w = (state_r == S_OUTCONV) ? (pp_iter_r_m2 >> 6) << 2 : 0;
	// the index of (00) in current iter
	// assign idx_w = (row_w << 6) + col_w;

	assign switch_conv_w = (((pp_iter_r + 1) & 7'b111_1111) < 64);// ~pp_iter_r[6]; // (01)..(03) --> (04)..(07)

	// S = 1, D = 1 : 
	// 06  07 | (00) (01) (02) (03) 04  05 06 07 | 00 01 
	assign img_00_w = (col_w > 60) ? 0 : ((switch_conv_w) ? sram00_out_data : sram04_out_data);
	assign img_01_w = (col_w > 60) ? 0 : ((switch_conv_w) ? sram01_out_data : sram05_out_data);
	assign img_02_w = (col_w > 60) ? 0 : ((switch_conv_w) ? sram02_out_data : sram06_out_data);
	assign img_03_w = (col_w > 60) ? 0 : ((switch_conv_w) ? sram03_out_data : sram07_out_data);
	// maybe outage
	assign img_04_w = (col_w >= 60 | (pp_iter_r >= 959) ) ? 0 : ( // | (col_w == 56 & row_w >= 62)
		(switch_conv_w) ? sram04_out_data : sram00_out_data
	); // 4032 ~ 4095
	assign img_05_w = (col_w >= 60 | (pp_iter_r >= 959)) ? 0 : (
		(switch_conv_w) ? sram05_out_data : sram01_out_data
	);
	assign img_06_w = (col_w > 60 | pp_iter_r < 12'd63) ? 0 : (
		(switch_conv_w) ? sram06_out_data : sram02_out_data
	); // 0~1023
	assign img_07_w = (col_w > 60 | pp_iter_r < 12'd63) ? 0 : (
		(switch_conv_w) ? sram07_out_data : sram03_out_data
	); // 0~1023

	// TODO: add SRAM reg to shorten ciritcal path
	reg  	[7:0] img_00_r, img_01_r, img_02_r, img_03_r, img_04_r, img_05_r, img_06_r, img_07_r;

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			img_00_r <= 0; img_01_r <= 0; img_02_r <= 0; img_03_r <= 0;
			img_04_r <= 0; img_05_r <= 0; img_06_r <= 0; img_07_r <= 0;
		end
		else begin
			img_00_r <= img_00_w;
			img_01_r <= img_01_w;
			img_02_r <= img_02_w;
			img_03_r <= img_03_w;
			img_04_r <= img_04_w;
			img_05_r <= img_05_w;
			img_06_r <= img_06_w;
			img_07_r <= img_07_w;
		end
	end

	// reg 	[MULT_SIZE-1:0]	P1_00_reg, P1_01_reg, P1_02_reg, P1_03_reg;
	reg 	[MULT_SIZE-1:0]	P1_00_00_reg, P1_00_01_reg, P1_00_02_reg;
	reg 	[MULT_SIZE-1:0]	P1_01_00_reg, P1_01_01_reg, P1_01_02_reg;
	reg 	[MULT_SIZE-1:0]	P1_02_00_reg, P1_02_01_reg, P1_02_02_reg;
	reg 	[MULT_SIZE-1:0]	P1_03_00_reg, P1_03_01_reg, P1_03_02_reg;
	
	// reg 	[MULT_SIZE-1:0]	P2_00_reg, P2_01_reg, P2_02_reg, P2_03_reg;
	reg 	[MULT_SIZE-1:0]	P2_00_00_reg, P2_00_01_reg, P2_00_02_reg;
	reg 	[MULT_SIZE-1:0]	P2_01_00_reg, P2_01_01_reg, P2_01_02_reg;
	reg 	[MULT_SIZE-1:0]	P2_02_00_reg, P2_02_01_reg, P2_02_02_reg;
	reg 	[MULT_SIZE-1:0]	P2_03_00_reg, P2_03_01_reg, P2_03_02_reg;
	reg  	[RES_SIZE-1:0]	P2_00_add_reg, P2_01_add_reg, P2_02_add_reg, P2_03_add_reg; 

	reg 	[MULT_SIZE-1:0]	P3_00_00_reg, P3_00_01_reg, P3_00_02_reg;
	reg 	[MULT_SIZE-1:0]	P3_01_00_reg, P3_01_01_reg, P3_01_02_reg;
	reg 	[MULT_SIZE-1:0]	P3_02_00_reg, P3_02_01_reg, P3_02_02_reg;
	reg 	[MULT_SIZE-1:0]	P3_03_00_reg, P3_03_01_reg, P3_03_02_reg;
	reg  	[RES_SIZE-1:0]	P3_00_add_reg, P3_01_add_reg, P3_02_add_reg, P3_03_add_reg;

	// reg 	[MULT_SIZE-1:0]	P3_00_reg, P3_01_reg, P3_02_reg, P3_03_reg; // no need cause max output is 4 bytes
	// switch to new column (clear out first register)
	wire   			flush_P1_w, flush_P3_w;
	assign flush_P1_w = ((dilation_sz_r == 1) & (row_w == 62)) | ((dilation_sz_r == 2) & ((row_w == 61) | (row_w == 60)) );
	assign flush_P3_w = ((dilation_sz_r == 1) & (row_w == 63)) | ((dilation_sz_r == 2) & ((row_w == 63) | (row_w == 62)) );

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			// P1_00_reg <= 0; P1_01_reg <= 0; P1_02_reg <= 0; P1_03_reg <= 0;
			// P2_00_reg <= 0; P2_01_reg <= 0; P2_02_reg <= 0; P2_03_reg <= 0;

			P1_00_00_reg <= 0; P1_00_01_reg <= 0; P1_00_02_reg <= 0;
			P1_01_00_reg <= 0; P1_01_01_reg <= 0; P1_01_02_reg <= 0;
			P1_02_00_reg <= 0; P1_02_01_reg <= 0; P1_02_02_reg <= 0;
			P1_03_00_reg <= 0; P1_03_01_reg <= 0; P1_03_02_reg <= 0;

			P2_00_00_reg <= 0; P2_00_01_reg <= 0; P2_00_02_reg <= 0;
			P2_01_00_reg <= 0; P2_01_01_reg <= 0; P2_01_02_reg <= 0;
			P2_02_00_reg <= 0; P2_02_01_reg <= 0; P2_02_02_reg <= 0;
			P2_03_00_reg <= 0; P2_03_01_reg <= 0; P2_03_02_reg <= 0;
			P2_00_add_reg <= 0; P2_01_add_reg <= 0; P2_02_add_reg <= 0; P2_03_add_reg <= 0;

			P3_00_00_reg <= 0; P3_00_01_reg <= 0; P3_00_02_reg <= 0;
			P3_01_00_reg <= 0; P3_01_01_reg <= 0; P3_01_02_reg <= 0;
			P3_02_00_reg <= 0; P3_02_01_reg <= 0; P3_02_02_reg <= 0;
			P3_03_00_reg <= 0; P3_03_01_reg <= 0; P3_03_02_reg <= 0;
			P3_00_add_reg <= 0; P3_01_add_reg <= 0; P3_02_add_reg <= 0; P3_03_add_reg <= 0;
		end
		else if (state_next == S_OUTCONV) begin // wait until SRAM is loaded

			if (dilation_sz_r == 1) begin
				// P1 -- PP register
				// 00_P1_r = 00_P3_r + 07 + 00 + 01 (weight: 0, 1, 2)
				// P1_00_reg <= (flush_P1_w ? 0 : signed_mult(img_07_w, weight_r[0]) + 
				// 			signed_mult(img_00_w, weight_r[1]) + signed_mult(img_01_w, weight_r[2]));
				P1_00_00_reg <= (flush_P1_w) ? 0 : signed_mult(img_07_r, weight_r[0]);
				P1_00_01_reg <= (flush_P1_w) ? 0 : signed_mult(img_00_r, weight_r[1]);
				P1_00_02_reg <= (flush_P1_w) ? 0 : signed_mult(img_01_r, weight_r[2]);

				// P1_01_reg <= (flush_P1_w ? 0 : signed_mult(img_00_r, weight_r[0]) + 
				// 			signed_mult(img_01_r, weight_r[1]) + signed_mult(img_02_r, weight_r[2]));
				P1_01_00_reg <= (flush_P1_w) ? 0 : signed_mult(img_00_r, weight_r[0]);
				P1_01_01_reg <= (flush_P1_w) ? 0 : signed_mult(img_01_r, weight_r[1]);
				P1_01_02_reg <= (flush_P1_w) ? 0 : signed_mult(img_02_r, weight_r[2]);

				// P1_02_reg <= (flush_P1_w ? 0 : signed_mult(img_01_r, weight_r[0]) + 
				// 			signed_mult(img_02_r, weight_r[1]) + signed_mult(img_03_r, weight_r[2]));
				P1_02_00_reg <= (flush_P1_w) ? 0 : signed_mult(img_01_r, weight_r[0]);
				P1_02_01_reg <= (flush_P1_w) ? 0 : signed_mult(img_02_r, weight_r[1]);
				P1_02_02_reg <= (flush_P1_w) ? 0 : signed_mult(img_03_r, weight_r[2]);

				// P1_03_reg <= (flush_P1_w ? 0 : signed_mult(img_02_r, weight_r[0]) + 
				// 			signed_mult(img_03_r, weight_r[1]) + signed_mult(img_04_r, weight_r[2]));
				P1_03_00_reg <= (flush_P1_w) ? 0 : signed_mult(img_02_r, weight_r[0]);
				P1_03_01_reg <= (flush_P1_w) ? 0 : signed_mult(img_03_r, weight_r[1]);
				P1_03_02_reg <= (flush_P1_w) ? 0 : signed_mult(img_04_r, weight_r[2]);

				// ================== P2 -- PP register ==================================
				// 00_P2_r = 00_P1_r + 07 + 00 + 01 (weight: 3, 4, 5)
				// P2_00_reg <= signed_mult(img_07_r, weight_r[3]) + signed_mult(img_00_r, weight_r[4]) + 
				// 			signed_mult(img_01_r, weight_r[5]) + P1_00_reg;
				P2_00_00_reg <= signed_mult(img_07_r, weight_r[3]);
				P2_00_01_reg <= signed_mult(img_00_r, weight_r[4]); 
				P2_00_02_reg <= signed_mult(img_01_r, weight_r[5]);
				P2_00_add_reg <= P1_00_00_reg + P1_00_01_reg + P1_00_02_reg;

				// P2_01_reg <= signed_mult(img_00_r, weight_r[3]) + signed_mult(img_01_r, weight_r[4]) + 
				// 			signed_mult(img_02_r, weight_r[5]) + P1_01_reg;
				P2_01_00_reg <= signed_mult(img_00_r, weight_r[3]);
				P2_01_01_reg <= signed_mult(img_01_r, weight_r[4]); 
				P2_01_02_reg <= signed_mult(img_02_r, weight_r[5]);
				P2_01_add_reg <= P1_01_00_reg + P1_01_01_reg + P1_01_02_reg;

				// P2_02_reg <= signed_mult(img_01_r, weight_r[3]) + signed_mult(img_02_r, weight_r[4]) + 
				// 			signed_mult(img_03_r, weight_r[5]) + P1_02_reg;
				P2_02_00_reg <= signed_mult(img_01_r, weight_r[3]);
				P2_02_01_reg <= signed_mult(img_02_r, weight_r[4]); 
				P2_02_02_reg <= signed_mult(img_03_r, weight_r[5]);
				P2_02_add_reg <= P1_02_00_reg + P1_02_01_reg + P1_02_02_reg;

				// P2_03_reg <= signed_mult(img_02_r, weight_r[3]) + signed_mult(img_03_r, weight_r[4]) + 
				// 			signed_mult(img_04_r, weight_r[5]) + P1_03_reg;
				P2_03_00_reg <= signed_mult(img_02_r, weight_r[3]);
				P2_03_01_reg <= signed_mult(img_03_r, weight_r[4]); 
				P2_03_02_reg <= signed_mult(img_04_r, weight_r[5]);
				P2_03_add_reg <= P1_03_00_reg + P1_03_01_reg + P1_03_02_reg;

				// ==================== P3 -- output ( at (0,0) is not valid ) ===============
				// 00_P3_r = 00_P2_r + 07 + 00 + 01 (weight: 6, 7, 8)
				// note at row 0, the latter add term should be 0

				// conv_out_data1_r <= (P2_00_reg + (flush_P3_w ? 0 : signed_mult(img_07_r, weight_r[6]) + 
				// 	signed_mult(img_00_r, weight_r[7]) + signed_mult(img_01_r, weight_r[8])));		
				P3_00_00_reg <= (flush_P3_w ? 0 : signed_mult(img_07_r, weight_r[6]));
				P3_00_01_reg <= (flush_P3_w ? 0 : signed_mult(img_00_r, weight_r[7]));
				P3_00_02_reg <= (flush_P3_w ? 0 : signed_mult(img_01_r, weight_r[8]));
				P3_00_add_reg <= P2_00_00_reg + P2_00_01_reg + P2_00_02_reg + P2_00_add_reg;

				// conv_out_data2_r <= (P2_01_reg + (flush_P3_w ? 0 : signed_mult(img_00_r, weight_r[6]) + 
				// 	signed_mult(img_01_r, weight_r[7]) + signed_mult(img_02_r, weight_r[8])));
				P3_01_00_reg <= (flush_P3_w ? 0 : signed_mult(img_00_r, weight_r[6]));
				P3_01_01_reg <= (flush_P3_w ? 0 : signed_mult(img_01_r, weight_r[7]));
				P3_01_02_reg <= (flush_P3_w ? 0 : signed_mult(img_02_r, weight_r[8]));
				P3_01_add_reg <= P2_01_00_reg + P2_01_01_reg + P2_01_02_reg + P2_01_add_reg;

				// conv_out_data3_r <= (P2_02_reg + (flush_P3_w ? 0 : signed_mult(img_01_r, weight_r[6]) + 
				// 	signed_mult(img_02_r, weight_r[7]) + signed_mult(img_03_r, weight_r[8])));
				P3_02_00_reg <= (flush_P3_w ? 0 : signed_mult(img_01_r, weight_r[6]));
				P3_02_01_reg <= (flush_P3_w ? 0 : signed_mult(img_02_r, weight_r[7]));
				P3_02_02_reg <= (flush_P3_w ? 0 : signed_mult(img_03_r, weight_r[8]));
				P3_02_add_reg <= P2_02_00_reg + P2_02_01_reg + P2_02_02_reg + P2_02_add_reg;

				// conv_out_data4_r <= (P2_03_reg + (flush_P3_w ? 0 : signed_mult(img_02_r, weight_r[6]) + 
				// 	signed_mult(img_03_r, weight_r[7]) + signed_mult(img_04_r, weight_r[8])));
				P3_03_00_reg <= (flush_P3_w ? 0 : signed_mult(img_02_r, weight_r[6]));
				P3_03_01_reg <= (flush_P3_w ? 0 : signed_mult(img_03_r, weight_r[7]));
				P3_03_02_reg <= (flush_P3_w ? 0 : signed_mult(img_04_r, weight_r[8]));
				P3_03_add_reg <= P2_03_00_reg + P2_03_01_reg + P2_03_02_reg + P2_03_add_reg;

				// ============== final result ================
				conv_out_data1_r <= P3_00_00_reg + P3_00_01_reg + P3_00_02_reg + P3_00_add_reg;
				conv_out_data2_r <= P3_01_00_reg + P3_01_01_reg + P3_01_02_reg + P3_01_add_reg;
				conv_out_data3_r <= P3_02_00_reg + P3_02_01_reg + P3_02_02_reg + P3_02_add_reg;
				conv_out_data4_r <= P3_03_00_reg + P3_03_01_reg + P3_03_02_reg + P3_03_add_reg;

			end

			else begin // dilation size == 2
				// P1 -- PP register
				// 00_P1_r = 00_P3_r + 06 + 00 + 02 (weight: 0, 1, 2)
				// P1_00_reg <= (flush_P1_w ? 0 : 
				// signed_mult(img_06_r, weight_r[0]) + signed_mult(img_00_r, weight_r[1]) + signed_mult(img_02_r, weight_r[2]));
				P1_00_00_reg <= (flush_P1_w) ? 0 : signed_mult(img_06_r, weight_r[0]);
				P1_00_01_reg <= (flush_P1_w) ? 0 : signed_mult(img_00_r, weight_r[1]);
				P1_00_02_reg <= (flush_P1_w) ? 0 : signed_mult(img_02_r, weight_r[2]);

				// P1_01_reg <= (flush_P1_w ? 0 : 
				// signed_mult(img_07_r, weight_r[0]) + signed_mult(img_01_r, weight_r[1]) + signed_mult(img_03_r, weight_r[2]));
				P1_01_00_reg <= (flush_P1_w) ? 0 : signed_mult(img_07_r, weight_r[0]);
				P1_01_01_reg <= (flush_P1_w) ? 0 : signed_mult(img_01_r, weight_r[1]);
				P1_01_02_reg <= (flush_P1_w) ? 0 : signed_mult(img_03_r, weight_r[2]);

				// P1_02_reg <= (flush_P1_w ? 0 : 
				// signed_mult(img_00_r, weight_r[0]) + signed_mult(img_02_r, weight_r[1]) + signed_mult(img_04_r, weight_r[2]));
				P1_02_00_reg <= (flush_P1_w) ? 0 : signed_mult(img_00_r, weight_r[0]);
				P1_02_01_reg <= (flush_P1_w) ? 0 : signed_mult(img_02_r, weight_r[1]);
				P1_02_02_reg <= (flush_P1_w) ? 0 : signed_mult(img_04_r, weight_r[2]);

				// P1_03_reg <= (flush_P1_w ? 0 : 
				// signed_mult(img_01_r, weight_r[0]) + signed_mult(img_03_r, weight_r[1]) + signed_mult(img_05_r, weight_r[2]));
				P1_03_00_reg <= (flush_P1_w) ? 0 : signed_mult(img_01_r, weight_r[0]);
				P1_03_01_reg <= (flush_P1_w) ? 0 : signed_mult(img_03_r, weight_r[1]);
				P1_03_02_reg <= (flush_P1_w) ? 0 : signed_mult(img_05_r, weight_r[2]);

				// ========================== P2 -- PP register ==================================
				// 00_P2_r = 00_P1_r + 07 + 00 + 01 (weight: 3, 4, 5)
				// P2_00_reg <= signed_mult(img_06_r, weight_r[3]) + signed_mult(img_00_r, weight_r[4]) + signed_mult(img_02_r, weight_r[5]) 
				// 			+ P1_00_reg;
				P2_00_00_reg <= signed_mult(img_06_r, weight_r[3]);
				P2_00_01_reg <= signed_mult(img_00_r, weight_r[4]);
				P2_00_02_reg <= signed_mult(img_02_r, weight_r[5]);
				P2_00_add_reg <= P1_00_00_reg + P1_00_01_reg + P1_00_02_reg;

				// P2_01_reg <= signed_mult(img_07_r, weight_r[3]) + signed_mult(img_01_r, weight_r[4]) + signed_mult(img_03_r, weight_r[5]) 
				// 			+ P1_01_reg;
				P2_01_00_reg <= signed_mult(img_07_r, weight_r[3]);
				P2_01_01_reg <= signed_mult(img_01_r, weight_r[4]);
				P2_01_02_reg <= signed_mult(img_03_r, weight_r[5]);
				P2_01_add_reg <= P1_01_00_reg + P1_01_01_reg + P1_01_02_reg;		

				// P2_02_reg <= signed_mult(img_00_r, weight_r[3]) + signed_mult(img_02_r, weight_r[4]) + signed_mult(img_04_r, weight_r[5]) 
				// 			+ P1_02_reg;
				P2_02_00_reg <= signed_mult(img_00_r, weight_r[3]);
				P2_02_01_reg <= signed_mult(img_02_r, weight_r[4]);
				P2_02_02_reg <= signed_mult(img_04_r, weight_r[5]);
				P2_02_add_reg <= P1_02_00_reg + P1_02_01_reg + P1_02_02_reg;

				// P2_03_reg <= signed_mult(img_01_r, weight_r[3]) + signed_mult(img_03_r, weight_r[4]) + signed_mult(img_05_r, weight_r[5]) 
				// 			+ P1_03_reg;
				P2_03_00_reg <= signed_mult(img_01_r, weight_r[3]);
				P2_03_01_reg <= signed_mult(img_03_r, weight_r[4]);
				P2_03_02_reg <= signed_mult(img_05_r, weight_r[5]);
				P2_03_add_reg <= P1_03_00_reg + P1_03_01_reg + P1_03_02_reg;

				// ==================== P3 -- output ( at (0,0) is not valid ) ===============
				// 00_P3_r = 00_P2_r + 07 + 00 + 01 (weight: 6, 7, 8)
				// note at row 0, the latter add term should be 0
	
				P3_00_00_reg <= (flush_P3_w ? 0 : signed_mult(img_06_r, weight_r[6]));
				P3_00_01_reg <= (flush_P3_w ? 0 : signed_mult(img_00_r, weight_r[7]));
				P3_00_02_reg <= (flush_P3_w ? 0 : signed_mult(img_02_r, weight_r[8]));
				P3_00_add_reg <= P2_00_00_reg + P2_00_01_reg + P2_00_02_reg + P2_00_add_reg;
				// OUT_TMP_00_r <= round2_8bit(P3_00_00_reg + P3_00_01_reg + P3_00_02_reg);

				// conv_out_data2_r <= (P2_01_reg + (flush_P3_w ? 0 : signed_mult(img_00_r, weight_r[6]) + 
				// 	signed_mult(img_01_r, weight_r[7]) + signed_mult(img_02_r, weight_r[8])));
				P3_01_00_reg <= (flush_P3_w ? 0 : signed_mult(img_07_r, weight_r[6]));
				P3_01_01_reg <= (flush_P3_w ? 0 : signed_mult(img_01_r, weight_r[7]));
				P3_01_02_reg <= (flush_P3_w ? 0 : signed_mult(img_03_r, weight_r[8]));
				P3_01_add_reg <= P2_01_00_reg + P2_01_01_reg + P2_01_02_reg + P2_01_add_reg;

				// conv_out_data3_r <= (P2_02_reg + (flush_P3_w ? 0 : signed_mult(img_01_r, weight_r[6]) + 
				// 	signed_mult(img_02_r, weight_r[7]) + signed_mult(img_03_r, weight_r[8])));
				P3_02_00_reg <= (flush_P3_w ? 0 : signed_mult(img_00_r, weight_r[6]));
				P3_02_01_reg <= (flush_P3_w ? 0 : signed_mult(img_02_r, weight_r[7]));
				P3_02_02_reg <= (flush_P3_w ? 0 : signed_mult(img_04_r, weight_r[8]));
				P3_02_add_reg <= P2_02_00_reg + P2_02_01_reg + P2_02_02_reg + P2_02_add_reg;

				// conv_out_data4_r <= (P2_03_reg + (flush_P3_w ? 0 : signed_mult(img_02_r, weight_r[6]) + 
				// 	signed_mult(img_03_r, weight_r[7]) + signed_mult(img_04_r, weight_r[8])));
				P3_03_00_reg <= (flush_P3_w ? 0 : signed_mult(img_01_r, weight_r[6]));
				P3_03_01_reg <= (flush_P3_w ? 0 : signed_mult(img_03_r, weight_r[7]));
				P3_03_02_reg <= (flush_P3_w ? 0 : signed_mult(img_05_r, weight_r[8]));
				P3_03_add_reg <= P2_03_00_reg + P2_03_01_reg + P2_03_02_reg + P2_03_add_reg;

				// ============== final result ================
				conv_out_data1_r <= P3_00_00_reg + P3_00_01_reg + P3_00_02_reg + P3_00_add_reg;
				conv_out_data2_r <= P3_01_00_reg + P3_01_01_reg + P3_01_02_reg + P3_01_add_reg;
				conv_out_data3_r <= P3_02_00_reg + P3_02_01_reg + P3_02_02_reg + P3_02_add_reg;
				conv_out_data4_r <= P3_03_00_reg + P3_03_01_reg + P3_03_02_reg + P3_03_add_reg;

				// conv_out_data1_r <= (P2_00_reg + (flush_P3_w ? 0 : 
				// 	signed_mult(img_06_r, weight_r[6]) + signed_mult(img_00_r, weight_r[7]) + signed_mult(img_02_r, weight_r[8])));
				// conv_out_data2_r <= (P2_01_reg + (flush_P3_w ? 0 : 
				// 	signed_mult(img_07_r, weight_r[6]) + signed_mult(img_01_r, weight_r[7]) + signed_mult(img_03_w, weight_r[8])));
				// conv_out_data3_r <= (P2_02_reg + (flush_P3_w ? 0 : 
				// 	signed_mult(img_00_w, weight_r[6]) + signed_mult(img_02_w, weight_r[7]) + signed_mult(img_04_w, weight_r[8])));
				// conv_out_data4_r <= (P2_03_reg + (flush_P3_w ? 0 : 
				// 	signed_mult(img_01_w, weight_r[6]) + signed_mult(img_03_w, weight_r[7]) + signed_mult(img_05_w, weight_r[8])));
			end
			
		end
	end

	// output address

	assign s2_odd_valid = (stride_sz_r == 1) | (~(row2_w & 1) & (stride_sz_r == 2)); // only even row for stride = 2
	assign s2_even_valid = (stride_sz_r == 1); 

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			o_out_addr1_r <= 1;
			o_out_addr2_r <= 1;
			o_out_addr3_r <= 1;
			o_out_addr4_r <= 1;
		end
		else if (state_next == S_OUTCONV) begin
			// P1
			// out 00_p2 = 00_P2_r + 07 + 00 + 01 (except for first round)
			// 02, 03 --> 32, 33 ; (row / 2) * 32
			// 0    4    8     12
			// |0 1| 2 3 | 4 5 | 6 7
			o_out_addr1_r <= (stride_sz_r == 1) ? (row2_w << 6) + col2_w : ((row2_w >> 1) << 5) + (col2_w >> 1);
			o_out_addr2_r <= (row2_w << 6) + col2_w + 1; // no output 2 when stride == 2
			o_out_addr3_r <= (stride_sz_r == 1) ? (row2_w << 6) + col2_w + 2 : ((row2_w >> 1) << 5) + (col2_w >> 1) + 1;
			o_out_addr4_r <= (row2_w << 6) + col2_w + 3; // no output 4 when stride == 2
			
		end
	end

// signed multiplication (36 bit)
// TODO: maybe use less bits?
// max: 01111110100000010000000 --> int + frac + sign = (8) + (7 + 7) + 1 = 23 bits
// min: 10000000100000000000000
	function automatic [MULT_SIZE-1:0] signed_mult;
		input [7:0] i_img;
		input [7:0]	i_weight;

		begin
			signed_mult = $signed({8'b0, i_img, 7'b0}) * $signed(i_weight); //$signed({ {15{i_weight[7]}}, i_weight});
		end
	endfunction

// round to 8 bit
// max: 010001110010100010010000000
// min: 101110000100100000000000000 --> 27 bits
	function automatic [7:0] round2_8bit;
		input [RES_SIZE-1:0] i_data; // [MULT_SIZE-1:0]
		reg   		do_round;
		reg   [RES_SIZE-1:0] sum_r;

		begin
			// round to nearest ([26]: signed, [21:14] --> integer, [13:0] --> fraction)
			// no need to round negative up
			do_round = (~i_data[26] & i_data[13]);
			sum_r = (do_round) ? i_data + 16'b0100_0000_0000_0000 : i_data;

			// clamp to [0, 255] 
			round2_8bit = (sum_r[26] == 1) ? 0 : ( // negative
					(sum_r[25:22] > 0) ? 8'd255 : // overflow 255
					sum_r[21:14]
			);
		end
	endfunction

// output for a single 3x3 convolution
	// function automatic [ 7: 0] conv1byte;
	// 	input [ 71: 0] 		i_img; // 9 8-bit input
	// 	input [ 71: 0]		i_weight;

	// 	reg [7:0]			img_i_r, weight_i_r, us_weight_i_r;
	// 	reg [MULT_SIZE-1:0]				tmp_r, sum_r; // (signed) treat i_img as 7 bit integer, 7 bit fraction --> 16 + 16 + log(9) + 1 = 37
	// 	reg  				do_round;
	// 	integer i;

	// 	begin
	// 		tmp_r = 0;
	// 		sum_r = 0;
	// 		for (i=0; i<72; i=i+8) begin // K=3 in this assignment
	// 			img_i_r = (i_img >> i) & 8'b1111_1111;
	// 			weight_i_r = (i_weight >> i) & 8'b1111_1111;
	// 			tmp_r = $signed({21'b0, img_i_r, 7'b0}) * $signed({ {29{weight_i_r[7]}}, weight_i_r});
	// 			sum_r = sum_r + tmp_r;
	// 		end

	// 		// round to nearest ([36]: signed, [30:15] --> integer, [13:0] --> fraction)
	// 		do_round = (~sum_r[36] & sum_r[13]) | (sum_r[36] & ~sum_r[13] & (sum_r[13:0] > 0));
	// 		sum_r = (do_round) ? sum_r + 37'b0100_0000_0000_0000 : sum_r;

	// 		// clamp to [0, 255] 
	// 		conv1byte = (sum_r[36] == 1) ? 0 : ( // negative
	// 				(sum_r[35:22] > 0) ? 8'd255 : // overflow 255
	// 				sum_r[21:14]
	// 		);
	// 	end 
	// endfunction


// =============== State 5: terminate ==============
	reg 			o_exe_finish_r;

	assign o_exe_finish = o_exe_finish_r;
	always @ (posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) 	o_exe_finish_r <= 0;
		else  			o_exe_finish_r <= isInvalid | (state_next == S_END);
	end


endmodule
