`timescale 1ns/100ps
`define CYCLE       10.0
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   120000

`ifdef p0
    `define Inst "../00_TB/PATTERN/p0/inst.dat"
	`define Data "../00_TB/PATTERN/p0/data.dat"
	`define Status "../00_TB/PATTERN/p0/status.dat"
`elsif p1
    `define Inst "../00_TB/PATTERN/p1/inst.dat"
	`define Data "../00_TB/PATTERN/p1/data.dat"
	`define Status "../00_TB/PATTERN/p1/status.dat"
`elsif p2
	`define Inst "../00_TB/PATTERN/p2/inst.dat"
	`define Data "../00_TB/PATTERN/p2/data.dat"
	`define Status "../00_TB/PATTERN/p2/status.dat"
`elsif p3
	`define Inst "../00_TB/PATTERN/p3/inst.dat"
	`define Data "../00_TB/PATTERN/p3/data.dat"
	`define Status "../00_TB/PATTERN/p3/status.dat"
`elsif h0 
    `define Inst "../00_TB/PATTERN/h0/inst.dat" 
    `define Data "../00_TB/PATTERN/h0/data.dat" 
    `define Status "../00_TB/PATTERN/h0/status.dat"

`elsif h1 
    `define Inst "../00_TB/PATTERN/h1/inst.dat" 
    `define Data "../00_TB/PATTERN/h1/data.dat" 
    `define Status "../00_TB/PATTERN/h1/status.dat"

`elsif h2 
    `define Inst "../00_TB/PATTERN/h2/inst.dat" 
    `define Data "../00_TB/PATTERN/h2/data.dat" 
    `define Status "../00_TB/PATTERN/h2/status.dat"

`elsif h3 
    `define Inst "../00_TB/PATTERN/h3/inst.dat" 
    `define Data "../00_TB/PATTERN/h3/data.dat" 
    `define Status "../00_TB/PATTERN/h3/status.dat"

`elsif h4 
    `define Inst "../00_TB/PATTERN/h4/inst.dat" 
    `define Data "../00_TB/PATTERN/h4/data.dat" 
    `define Status "../00_TB/PATTERN/h4/status.dat"

`elsif h5 
    `define Inst "../00_TB/PATTERN/h5/inst.dat" 
    `define Data "../00_TB/PATTERN/h5/data.dat" 
    `define Status "../00_TB/PATTERN/h5/status.dat"

`elsif h6 
    `define Inst "../00_TB/PATTERN/h6/inst.dat" 
    `define Data "../00_TB/PATTERN/h6/data.dat" 
    `define Status "../00_TB/PATTERN/h6/status.dat"

`elsif h7 
    `define Inst "../00_TB/PATTERN/h7/inst.dat" 
    `define Data "../00_TB/PATTERN/h7/data.dat" 
    `define Status "../00_TB/PATTERN/h7/status.dat"

`elsif h8 
    `define Inst "../00_TB/PATTERN/h8/inst.dat" 
    `define Data "../00_TB/PATTERN/h8/data.dat" 
    `define Status "../00_TB/PATTERN/h8/status.dat"

`elsif h9 
    `define Inst "../00_TB/PATTERN/h9/inst.dat" 
    `define Data "../00_TB/PATTERN/h9/data.dat" 
    `define Status "../00_TB/PATTERN/h9/status.dat"

`elsif h10 
    `define Inst "../00_TB/PATTERN/h10/inst.dat" 
    `define Data "../00_TB/PATTERN/h10/data.dat" 
    `define Status "../00_TB/PATTERN/h10/status.dat"

`elsif h11 
    `define Inst "../00_TB/PATTERN/h11/inst.dat" 
    `define Data "../00_TB/PATTERN/h11/data.dat" 
    `define Status "../00_TB/PATTERN/h11/status.dat"

`elsif h12 
    `define Inst "../00_TB/PATTERN/h12/inst.dat" 
    `define Data "../00_TB/PATTERN/h12/data.dat" 
    `define Status "../00_TB/PATTERN/h12/status.dat"

`elsif h13 
    `define Inst "../00_TB/PATTERN/h13/inst.dat" 
    `define Data "../00_TB/PATTERN/h13/data.dat" 
    `define Status "../00_TB/PATTERN/h13/status.dat"

`elsif h14 
    `define Inst "../00_TB/PATTERN/h14/inst.dat" 
    `define Data "../00_TB/PATTERN/h14/data.dat" 
    `define Status "../00_TB/PATTERN/h14/status.dat"

`elsif h15 
    `define Inst "../00_TB/PATTERN/h15/inst.dat" 
    `define Data "../00_TB/PATTERN/h15/data.dat" 
    `define Status "../00_TB/PATTERN/h15/status.dat"

`elsif h16 
    `define Inst "../00_TB/PATTERN/h16/inst.dat" 
    `define Data "../00_TB/PATTERN/h16/data.dat" 
    `define Status "../00_TB/PATTERN/h16/status.dat"

`elsif h17 
    `define Inst "../00_TB/PATTERN/h17/inst.dat" 
    `define Data "../00_TB/PATTERN/h17/data.dat" 
    `define Status "../00_TB/PATTERN/h17/status.dat"

`elsif h18 
    `define Inst "../00_TB/PATTERN/h18/inst.dat" 
    `define Data "../00_TB/PATTERN/h18/data.dat" 
    `define Status "../00_TB/PATTERN/h18/status.dat"

`elsif h19 
    `define Inst "../00_TB/PATTERN/h19/inst.dat" 
    `define Data "../00_TB/PATTERN/h19/data.dat" 
    `define Status "../00_TB/PATTERN/h19/status.dat"
`else
	`define Inst "../00_TB/PATTERN/p0/inst.dat"
	`define Data "../00_TB/PATTERN/p0/data.dat"
	`define Status "../00_TB/PATTERN/p0/status.dat"
`endif

module testbed;

	reg  rst_n;
	reg  clk = 0;
	wire            dmem_we;
	wire [ 31 : 0 ] dmem_addr;
	wire [ 31 : 0 ] dmem_wdata;
	wire [ 31 : 0 ] dmem_rdata;
	wire [  2 : 0 ] mips_status;
	wire            mips_status_valid;
    reg  [ 31 : 0 ] i_rdata_r;

	//add
	reg [31:0] input_data [0:2047];
	reg [2:0] input_status [0:1023];
	reg [31:0] golden_data [0:2047];
	reg [2:0] golden_status [0:1023];

	integer output_end, status_end;
    integer j, k;
    integer correct_status, correct_data, error_status, error_data;

	core u_core (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.o_status(mips_status),
		.o_status_valid(mips_status_valid),
		.o_we(dmem_we),
		.o_addr(dmem_addr),
		.o_wdata(dmem_wdata),
		.i_rdata(i_rdata_r)
	);

	data_mem  u_data_mem (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.i_we(dmem_we),
		.i_addr(dmem_addr),
		.i_wdata(dmem_wdata),
		.o_rdata(dmem_rdata)
	);

	always #(`HCYCLE) clk = ~clk;

	// load data memory
	initial begin 
		rst_n = 1;
		#(0.25 * `CYCLE) rst_n = 0;
		#(`CYCLE) rst_n = 1;
		$readmemb (`Inst, u_data_mem.mem_r);
		$readmemb (`Data, golden_data);
		$readmemb (`Status, golden_status);
		#(`MAX_CYCLE * `CYCLE);
        $display("Error! Runtime exceeded!");
        $finish;
	end

	// initial begin
    //    $fsdbDumpfile("CPU.fsdb");
    //    $fsdbDumpvars(0, testbed, "+mda");
    // end
    // input
	always @ (posedge clk) begin
		if (!rst_n) i_rdata_r <= 0;
		else		i_rdata_r <= dmem_rdata;
	end

    // Output
    initial begin
        correct_status = 0;
		correct_data = 0;
        error_status = 0;
		error_data = 0;
        status_end = 0;
		output_end = 0;

        // reset
        wait (rst_n === 1'b0);
        wait (rst_n === 1'b1);

        // start
        @(posedge clk);

        // loop
        k = 0;
        while (k < 1024 && !status_end) begin
            @(negedge clk);
            if (mips_status_valid) begin
                if (mips_status === golden_status[k]) begin
                    correct_status = correct_status + 1;
					if(mips_status == 3'd5 || mips_status == 3'd6)
						status_end = 1;
                end
                else begin
                    error_status = error_status + 1;
                    $display(
                        "Status[%d]: Error! Golden_S=%b, Yours=%b",
                        k,
                        golden_status[k],
                        mips_status
                    );
					if(mips_status == 3'd5 || mips_status == 3'd6)
						status_end = 1;
                end
                k = k+1;
            end
            @(posedge clk);
        end

		j = 0;
		while(j < 2048) begin
			if(u_data_mem.mem_r[j] === golden_data[j]) begin
				correct_data = correct_data + 1;
			end
			else begin
				error_data = error_data + 1;
				$display (
                        "Data[%d]: Error! Golden_D=%b, Yours=%b", 
                        j, golden_data[j], u_data_mem.mem_r[j]
				); 
			end
			j=j+1;
		end

        // final
        output_end = 1;
    end

    // Result
    initial begin
        wait (output_end);

        if (error_status === 0 && correct_status === k && error_data === 0 && correct_data === j) begin
            $display("----------------------------------------------");
            $display("-                 ALL PASS!                  -");
            $display("----------------------------------------------");
        end
        else begin
            $display("----------------------------------------------");
            $display("  Wrong! Status Error: %d ,Data Error: %d     ", error_status, error_data);
            $display("----------------------------------------------");
        end

        # (2 * `CYCLE);
        $finish;
    end

	initial begin
        # (`MAX_CYCLE * `CYCLE);
        $display("------------------------------------");
        $display("Processing time exceed 120000 cycles");
        $display("------------------------------------");
        $finish;
    end

endmodule