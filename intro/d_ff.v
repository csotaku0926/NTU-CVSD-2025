module d_ff (
    output reg q, // only "reg" (stores data) can be assigned in always or initial block
    input d,
    input clk
);

always @ (posedge clk) begin
    q <= d;
end

endmodule