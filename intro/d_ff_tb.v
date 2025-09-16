module d_ff_tb;

reg d, clk;
wire q;

// instantiate d flip-flop
d_ff dut (
    .q(q),
    .d(d),
    .clk(clk)
);

// clock generation
always #5 clk = ~clk;

// test bench init
initial begin
    $dumpfile("d_ff.fsdb"); // for nWave
    $dumpvars(0, d_ff_tb);

    // initialize inputs
    d = 0;
    clk = 0;

    #10 d = 1;
    #10 d = 0;
    #10 d = 1;

    #10 $finish;
end

endmodule