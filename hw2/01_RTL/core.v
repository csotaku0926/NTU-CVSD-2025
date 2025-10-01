`include "define.v"
`include "alu.v"

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
    reg    [2:0]            o_status_r;
    reg                     o_status_valid_r;
    
    reg    [ADDR_WIDTH-1:0] o_addr_r;
    reg    [DATA_WIDTH-1:0] o_wdata_r;
    reg                     o_we_r;

    reg    [2:0]            state_r, state_w; // FSM state
    reg    [ADDR_WIDTH-1:0] pc_r; // program counter

    // ALU
    reg    [2:0]            alu_op_r;

    // define instruction mapping
    // R-type
    wire   [6:0]            opcode_w;
    wire   [4:0]            rd_w; // rd / fd
    wire   [2:0]            funct3_w;
    wire   [4:0]            r1_w, r2_w;
    wire   [6:0]            funct7_w;
    // I-type
    wire   [11:0]           imm_i_w;
    // S-type
    wire   [11:0]           imm_s_w;
    // B-type (imm is implictly 2-bit alignment)
    wire   [11:0]           imm_b_w;      
    // U-type
    wire   [19:0]           imm_u_w;

    integer i;

    // ???
    wire                    isreg_a_w, isreg_b_w, isreg_write_w;

// states
localparam S_IDLE = 3'd0;
localparam S_IF = 3'd1;
localparam S_ID = 3'd2;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //
assign o_status = o_status_r;
assign o_status_valid = o_status_valid_r;
assign o_addr = o_addr_r;
assign o_wdata = o_wdata_r;
assign o_we = o_we_r;

// inst
assign opcode_w = i_rdata[6:0];
assign rd_w = i_rdata[11:7];
assign funct3_w = i_rdata[14:12];
assign r1_w = i_rdata[19:15];
assign r2_w = i_rdata[24:20];
assign funct7_w = i_rdata[31:25];

assign imm_i_w = i_rdata[31:20];
assign imm_s_w = { i_rdata[31:25], i_rdata[11:7] };
assign imm_b_w = { i_rdata[31], i_rdata[7], i_rdata[30:25], i_rdata[11:8] };
assign imm_u_w = i_rdata[31:12];

// reg file
assign isreg_a_w = (opcode_w != `OP_FSUB); // not 7'b1010011
assign isreg_b_w = ((opcode_w != `OP_FSUB) && (opcode_w)); // not FSUB and not fsw

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //

// state reg
always @ (posedge i_clk or negedge i_rst_n) begin
    // async reset
    if (!i_rst_n) state_r <= S_IDLE;
    else state_r <= state_w;
end

// next state logic
always @ (*) begin
    case (state_r)
        S_IDLE: begin
            o_status_r <= 0;
            o_status_valid_r <= 0;
            o_addr_r <= 0;
            o_wdata_r <= 0;
            o_we_r <= 0;
            pc_r <= 0;

            state_w <= S_IF;
        end
        S_IF: begin
            // fetch instruction from inst mem (0~4095)
            o_we_r <= 0;
            o_addr_r <= pc_r;

            state_w <= S_ID; // i_rdata is to be expected in the next cycle
        end
        S_ID: begin
            // instruction decoding
            case (opcode_w)
                `OP_ADDI: alu_op_r = `ALU_ADD;

            endcase
        end
        default: state_w <= S_IDLE;
    endcase
end

// plug in to reg file
reg_file u_reg_file(
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_addr_a(r1_w),
    .i_isreg_a()
);

// plug in to ALU
alu u_alu(
    .i_op(alu_op_r),
    .i_data_a(),
    .i_data_b(),
    .o_data(),
    .o_overflow()
);

endmodule