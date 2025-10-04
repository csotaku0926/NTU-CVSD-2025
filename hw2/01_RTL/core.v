module core #( // DO NOT MODIFY INTERFACE!!!
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) ( 
    input i_clk,
    input i_rst_n,

    // Testbench IOs
    output [2:0] o_status, 
    output       o_status_valid,

    // Memory IOs
    output [ADDR_WIDTH-1:0] o_addr,
    output [DATA_WIDTH-1:0] o_wdata,
    output                  o_we,
    input  [DATA_WIDTH-1:0] i_rdata
);

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
// ---- Add your own wires and registers here if needed ---- //
// ================  handle output  ======================
    reg    [2:0]            o_status_r;
    wire   [2:0]            o_status_w;
    reg                     o_status_valid_r;
    wire                    o_status_valid_w;

    always @ (posedge i_clk or negedge i_rst_n) begin
        // async reset
        if (!i_rst_n) begin
            o_status_r <= 0;
            o_status_valid_r <= 0;
        end
        else begin
            o_status_r <= o_status_w;
            o_status_valid_r <= o_status_valid_w;
        end
    end

    assign o_status = o_status_r;
    assign o_status_valid = o_status_valid_r;


// ================= instruction mapping ============================
    // R-type
    wire   [6:0]            opcode_w;
    wire   [4:0]            rd_w; // rd / fd
    wire   [2:0]            funct3_w;
    wire   [4:0]            r1_w, r2_w;
    wire   [6:0]            funct7_w;
    // imm for I-type, S-type and B-type (implictly 2-bit alignment)(12-bit), U-type (20-bit)
    wire   [DATA_WIDTH-1:0] imm_w;
    wire                    is_r_type, is_i_type, is_s_type, is_b_type, is_u_type, is_eof;
    wire                    is_load_op;

    // inst
    assign opcode_w = i_rdata[6:0];
    assign rd_w = i_rdata[11:7];
    assign funct3_w = i_rdata[14:12];
    assign r1_w = i_rdata[19:15];
    assign r2_w = i_rdata[24:20];
    assign funct7_w = i_rdata[31:25];

    // types
    assign is_r_type = (opcode_w == `OP_SUB) | (opcode_w == `OP_FSUB);
    assign is_i_type = (opcode_w == `OP_ADDI) | (opcode_w == `OP_LW) | (opcode_w == `OP_JALR) | (opcode_w == `OP_FLW);
    assign is_s_type = (opcode_w == `OP_SW) | (opcode_w == `OP_FSW);
    assign is_b_type = (opcode_w == `OP_BEQ);
    assign is_u_type = (opcode_w == `OP_AUIPC);
    assign is_load_op = (opcode_w == `OP_LW) | (opcode_w == `OP_FLW);
    assign is_eof = (opcode_w == `OP_EOF);

    assign imm_w = (is_i_type ? { {20{i_rdata[31]}}, i_rdata[31:20] } : (
                    is_s_type ? { {20{i_rdata[31]}}, i_rdata[31:25], i_rdata[11:7] } : (
                    is_b_type ? { {20{i_rdata[31]}}, i_rdata[31], i_rdata[7], i_rdata[30:25], i_rdata[11:8] } : 
                    { i_rdata[31:12], {12{i_rdata[31]}} } // U type: imm << 12 (no overflow considered)
    )));


// ================  state machine  ======================
    reg    [2:0]            state_r, state_next; // FSM state

    // invalid case --> S_END
    wire                    is_invalid_w;
    wire                    alu_is_overflow_w;
    wire                    is_invalid_addr_w;

    localparam S_IDLE = 3'd0;
    localparam S_IF = 3'd1;
    localparam S_CALC = 3'd2;
    localparam S_WB = 3'd3;
    localparam S_END = 3'd4;

    assign is_invalid_w = (alu_is_overflow_w) | (is_invalid_addr_w);

    always @ (*) begin
        case (state_r)
            S_IDLE: state_next = S_IF;
            S_IF: state_next = S_CALC;
            S_CALC: state_next = (is_eof | is_invalid_w) ? S_END : S_WB;
            S_WB: state_next = S_IF;
            S_END: state_next = S_END;
            default: state_next = S_IDLE;
        endcase
    end

    always @ (posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)   state_r <= S_IDLE;
        else            state_r <= state_next;
    end

// =================  plug in to reg file  ====================
    wire                    isreg_a_w, isreg_b_w, isreg_write_w;
    wire   [DATA_WIDTH-1:0] data_a_fromReg_w, data_b_fromReg_w;
    wire   [DATA_WIDTH-1:0] writeData_w;
    wire                    doWrite_w;

    assign isreg_a_w = (opcode_w != `OP_FSUB); // not 7'b1010011
    assign isreg_b_w = ((opcode_w != `OP_FSUB) && (opcode_w != `OP_FSW)); // not FSUB and not fsw
    assign doWrite_w = (state_r == S_WB) & (~is_s_type) & (~is_b_type) & (opcode_w != `OP_EOF);
    assign isreg_write_w = (opcode_w != `OP_FSUB); // store to reg or float

    reg_file u_reg_file(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_addr_a(r1_w),
        .i_isreg_a(isreg_a_w),
        .i_addr_b(r2_w),
        .i_isreg_b(isreg_b_w),
        .i_doWrite(doWrite_w),
        .i_writeisReg(isreg_write_w),
        .i_writeAddr(rd_w),
        .i_writeData(writeData_w),
        .o_data_a(data_a_fromReg_w),
        .o_data_b(data_b_fromReg_w)
    );

// =============  plug in to ALU  ==================
    reg    [4:0]            alu_op_r;
    wire   [DATA_WIDTH-1:0] alu_o_data_w;
    wire   [DATA_WIDTH-1:0] data_a_forALU_w, data_b_forALU_w;
    reg    [ADDR_WIDTH-1:0] pc_r; // program counter

 
    assign data_a_forALU_w = (is_u_type ? pc_r : data_a_fromReg_w); // r1 except for U type
    assign data_b_forALU_w = ((is_r_type | is_b_type) ? data_b_fromReg_w : imm_w); 
    // R, B type: data_b_from_reg, I, S, U type: imm

    // 1005 TODO: FLW
    always @ (*) begin
        case (opcode_w)
            `OP_ADDI    :   alu_op_r = `ALU_ADD;
            `OP_SUB     :   alu_op_r = ((funct3_w == `FUNCT3_SUB) ? `ALU_SUB : 
                                        (funct3_w == `FUNCT3_SLT) ? `ALU_SLT : `ALU_SRL); // SUB, SLT, SRL have same opcode
            `OP_SW      :   alu_op_r = `ALU_ADD;
            `OP_LW      :   alu_op_r = `ALU_ADD;
            `OP_AUIPC   :   alu_op_r = `ALU_ADD;
            default     :   alu_op_r = `ALU_ADD;

        endcase
    end

    alu u_alu(
        .i_op(alu_op_r),
        .i_data_a(data_a_forALU_w),
        .i_data_b(data_b_forALU_w),
        .o_data(alu_o_data_w),
        .o_overflow(alu_is_overflow_w)
    );

    // is calculated saved data MEM address valid ? (4096 ~ 8191)
    assign is_invalid_addr_w = (is_s_type | is_load_op) & ~((32'd4096 <= alu_o_data_w) & (alu_o_data_w <= 32'd8191));

    // reg write is dependent on ALU
    assign writeData_w = alu_o_data_w;

// ================== output handling 2 ============================

    // you should set invalid checking first!
    assign o_status_w = (is_invalid_w ? `INVALID_TYPE : (
                        is_i_type ? `I_TYPE : (
                        is_s_type ? `S_TYPE : (
                        is_b_type ? `B_TYPE : (
                        is_u_type ? `U_TYPE : (
                        is_r_type ? `R_TYPE : `EOF_TYPE
    ))))));

    assign o_status_valid_w = (state_next == S_WB) | (state_next == S_END);

// =================== read from / write to MEM & PC update  ===================
    reg    [ADDR_WIDTH-1:0] o_addr_r;
    reg    [DATA_WIDTH-1:0] o_wdata_r;
    reg                     o_we_r;

    always @ (posedge i_clk or negedge i_rst_n) begin
        // async reset
        if (!i_rst_n) begin
            o_we_r <= 0;
            o_addr_r <= 0;
            o_wdata_r <= 0;
            pc_r <= 0;
        end
        else if (state_next == S_IF) begin
            // fetch instruction from inst mem (0~4095)
            o_we_r <= 0;
            o_addr_r <= pc_r;
            o_wdata_r <= 0;
        end
        else if (state_next == S_CALC && is_load_op) begin
            // load data from MEM (lw, flw)
            o_we_r <= 0;
            o_addr_r <= alu_o_data_w;
            o_wdata_r <= 0;
        end
        else if (state_next == S_WB) begin
            // write result back to MEM (only s type)
            // MEM[$r1 + im] = $r2
            o_we_r <= is_s_type;
            o_addr_r <= alu_o_data_w;
            o_wdata_r <= data_b_fromReg_w;
            // update pc (TODO: B type)
            pc_r <= pc_r + 4;
        end
        else begin
            o_we_r <= 0;
        end
    end
    
    assign o_we = o_we_r;
    assign o_addr = o_addr_r;
    assign o_wdata = o_wdata_r;

endmodule