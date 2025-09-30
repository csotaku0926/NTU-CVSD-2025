`include "define.v"

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
            
        end
        default: state_w <= S_IDLE;
    endcase
end

endmodule