`timescale 1ns/100ps
`define RST_DELAY   1.25
`define CYCLE       10.0
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   120000
// EOF type status
`define INVALID_TYPE 5
`define EOF_TYPE 6

`ifdef p0
	`define INST "../00_TB/PATTERN/p0/inst.dat"
    `define DATA "../00_TB/PATTERN/p0/data.dat"
	`define STAT "../00_TB/PATTERN/p0/status.dat"
	`define STAT_LEN 69
`elsif p1
	`define INST "../00_TB/PATTERN/p1/inst.dat"
    `define DATA "../00_TB/PATTERN/p1/data.dat"
	`define STAT "../00_TB/PATTERN/p1/status.dat"
	`define STAT_LEN 12
`elsif p2
	`define INST "../00_TB/PATTERN/p2/inst.dat"
	`define DATA "../00_TB/PATTERN/p2/data.dat"
	`define STAT "../00_TB/PATTERN/p2/status.dat"
	`define STAT_LEN 45
`elsif p3
	`define INST "../00_TB/PATTERN/p3/inst.dat"
	`define DATA "../00_TB/PATTERN/p3/data.dat"
	`define STAT "../00_TB/PATTERN/p3/status.dat"
	`define STAT_LEN 510
`else
	`define INST "../00_TB/PATTERN/p0/inst.dat"
	`define DATA "../00_TB/PATTERN/p0/data.dat"
	`define STAT "../00_TB/PATTERN/p0/status.dat"
	`define STAT_LEN 69
`endif

module testbed #(
	parameter DATA_W = 32;
	parameter STAT_W = 3;
) ();

	reg  rst_n;
	reg  clk;
	wire            		dmem_we;
	wire [ DATA_W-1 : 0 ] dmem_addr;
	wire [ DATA_W-1 : 0 ] dmem_wdata;
	wire [ DATA_W-1 : 0 ] dmem_rdata;
	wire [ STAT_W-1 : 0 ] mips_status;
	wire            mips_status_valid;

	// TB variables
	reg	 [ STAT_W-1 : 0 ] o_status_ram  [0:`STAT_LEN-1];
	reg	 [ STAT_W-1 : 0 ] golden_status [0:`STAT_LEN-1];
	reg 					is_eof;

	integer output_end;
	integer i;

	core u_core (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.o_status(mips_status),
		.o_status_valid(mips_status_valid),
		.o_we(dmem_we),
		.o_addr(dmem_addr),
		.o_wdata(dmem_wdata),
		.i_rdata(dmem_rdata)
	);

	data_mem  u_data_mem (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.i_we(dmem_we),
		.i_addr(dmem_addr),
		.i_wdata(dmem_wdata),
		.o_rdata(dmem_rdata)
	);

	// load data memory
	initial begin 
		$readmemb (`INST, u_data_mem.mem_r);
		$readmemb (`STAT, golden_status);
	end

	// clock module
    clk_gen u_clk_gen (
        .clk   (clk  ),
        .rst_n (rst_n)
    );

	// dump fsdb file
	initial begin
		$fsdbDumpfile("core.fsdb");
		$fsdbDumpvars(0, testbed, "+mda");
	end

	// Output
	initial begin
		output_end = 0;

		// reset
        wait (rst_n === 1'b0);
        #(0.1 * `PERIOD);
        if (
            (mips_status     	!== 1'b0) ||
            (mips_status_valid 	!== 1'b0) ||
            (dmem_wdata     	!== {DATA_W{1'b0}}) ||
			(dmem_addr			!== {DATA_W{1'b0}}) ||
			(dmem_we			!== 1'b0)
        ) begin
            $display("Reset: Error! Output not reset to 0");
        end
        wait (rst_n === 1'b1);

		// start
		@(posedge clk);

		// loop
		i = 0;
		is_eof = 1'b0;
		while (i < `STAT_LEN && is_eof == 1'b0) begin
			@(negedge clk);
			if (mips_status_valid === 1) begin
				o_status_ram[i] = mips_status;
				is_eof = (mips_status == `INVALID_TYPE) | (mips_status == `EOF_TYPE);
				i = i+1;
			end
			@(posedge clk);
		end

		// final
        @(negedge clk);
        output_end = 1;
	end

	// Result
    initial begin
        wait (output_end);

        $display("Compute finished, start validating result...");
        validate();
        $display("Simulation finish");
        # (2 * `PERIOD);
        $finish;
    end

endmodule

module clk_gen (
	output reg clk,
	output reg rst_n
);
	always #(`HCYCLE) clk = ~clk;
	initial begin
		clk = 0;
		rst_n = 1; #(0.25 					* `CYCLE); 
		rst_n = 0; #((`RST_DELAY - 0.25) 	* `CYCLE); 
		rst_n = 1; # (`MAX_CYCLE			* `CYCLE);
		$display("[Error] T.L.E (Time Limit Exceed)... Clockhead");
		$finish;
	end
endmodule