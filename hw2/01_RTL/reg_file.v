module reg_file #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5
) (
    input                       i_clk,
    input                       i_rst_n,
    input  [ADDR_WIDTH-1:0]     i_addr_a,
    input                       i_isreg_a, // int or float reg?
    input  [ADDR_WIDTH-1:0]     i_addr_b,
    input                       i_isreg_b,
    input                       i_doWrite,
    input                       i_writeisReg,
    input  [ADDR_WIDTH-1:0]     i_writeAddr,
    input  [DATA_WIDTH-1:0]     i_writeData,

    output [DATA_WIDTH-1:0]     o_data_a,
    output [DATA_WIDTH-1:0]     o_data_b    
);

    // register file (32 signed 32-bit & 32 single precision floating point)
    reg    [DATA_WIDTH-1:0]     reg_mem_r [0:31]; // int register
    reg    [DATA_WIDTH-1:0]     flt_mem_r [0:31]; // float number

    integer i;

    // r1 & r2
    assign o_data_a = (i_isreg_a) ? reg_mem_r[i_addr_a] : flt_mem_r[i_addr_a];
    assign o_data_b = (i_isreg_b) ? reg_mem_r[i_addr_b] : flt_mem_r[i_addr_b];

    always @ (posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (i=0; i<32; i=i+1) begin
                reg_mem_r[i] <= 0;
                flt_mem_r[i] <= 0;
            end
        end
        else if (i_doWrite) begin
            if (i_writeisReg) reg_mem_r[i_writeAddr] <= i_writeData;
            else              flt_mem_r[i_writeAddr] <= i_writeData;
        end
    end

endmodule