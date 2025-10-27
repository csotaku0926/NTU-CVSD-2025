/////////////////////////////////////////////////////////////
// Created by: Synopsys Design Compiler(R)
// Version   : U-2022.12
// Date      : Sun Oct 26 16:17:30 2025
/////////////////////////////////////////////////////////////


module ALU ( alu_out, instruction, inputA, inputB, clk, reset );
  output [7:0] alu_out;
  input [3:0] instruction;
  input [7:0] inputA;
  input [7:0] inputB;
  input clk, reset;
  wire   N0, N1, N2, N3, N4, N5, N6, N7, N8, N9, N10, N11, N12, N13, N14, N15,
         N16, N17, N18, N19, N20, N21, N22, N23, N24, N25, N26, N27, N28, N29,
         N30, N31, N32, N33, N34, N35, N36, N37, N38, N39, N40, N41, N42, N43,
         N44, N45, N46, N47, N48, N49, N50, N51, N52, N53, N54, N55, N56, N57,
         N58, N59, N60, N61, N62, N63, N64, N65, N66, N67, N68, N69, N70, N71,
         N72, N73, N74, N75, N76, N77, N78;
  wire   [7:0] reg_A;
  wire   [7:0] reg_B;
  wire   [3:0] reg_ins;
  wire   [7:0] X;
  wire   [7:0] inputB_inv;

  \**SEQGEN**  \reg_B_reg[7]  ( .clear(N8), .preset(1'b0), .next_state(
        inputB[7]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_B[7]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_B_reg[6]  ( .clear(N8), .preset(1'b0), .next_state(
        inputB[6]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_B[6]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_B_reg[5]  ( .clear(N8), .preset(1'b0), .next_state(
        inputB[5]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_B[5]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_B_reg[4]  ( .clear(N8), .preset(1'b0), .next_state(
        inputB[4]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_B[4]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_B_reg[3]  ( .clear(N8), .preset(1'b0), .next_state(
        inputB[3]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_B[3]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_B_reg[2]  ( .clear(N8), .preset(1'b0), .next_state(
        inputB[2]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_B[2]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_B_reg[1]  ( .clear(N8), .preset(1'b0), .next_state(
        inputB[1]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_B[1]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_B_reg[0]  ( .clear(N8), .preset(1'b0), .next_state(
        inputB[0]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_B[0]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_ins_reg[3]  ( .clear(N8), .preset(1'b0), .next_state(
        instruction[3]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_ins[3]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(
        1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_ins_reg[2]  ( .clear(N8), .preset(1'b0), .next_state(
        instruction[2]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_ins[2]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(
        1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_ins_reg[1]  ( .clear(N8), .preset(1'b0), .next_state(
        instruction[1]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_ins[1]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(
        1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_ins_reg[0]  ( .clear(N8), .preset(1'b0), .next_state(
        instruction[0]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_ins[0]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(
        1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \alu_out_reg[7]  ( .clear(N8), .preset(1'b0), .next_state(X[7]), 
        .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(alu_out[7]), 
        .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), 
        .synch_enable(1'b1) );
  \**SEQGEN**  \alu_out_reg[6]  ( .clear(N8), .preset(1'b0), .next_state(X[6]), 
        .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(alu_out[6]), 
        .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), 
        .synch_enable(1'b1) );
  \**SEQGEN**  \alu_out_reg[5]  ( .clear(N8), .preset(1'b0), .next_state(X[5]), 
        .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(alu_out[5]), 
        .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), 
        .synch_enable(1'b1) );
  \**SEQGEN**  \alu_out_reg[4]  ( .clear(N8), .preset(1'b0), .next_state(X[4]), 
        .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(alu_out[4]), 
        .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), 
        .synch_enable(1'b1) );
  \**SEQGEN**  \alu_out_reg[3]  ( .clear(N8), .preset(1'b0), .next_state(X[3]), 
        .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(alu_out[3]), 
        .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), 
        .synch_enable(1'b1) );
  \**SEQGEN**  \alu_out_reg[2]  ( .clear(N8), .preset(1'b0), .next_state(X[2]), 
        .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(alu_out[2]), 
        .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), 
        .synch_enable(1'b1) );
  \**SEQGEN**  \alu_out_reg[1]  ( .clear(N8), .preset(1'b0), .next_state(X[1]), 
        .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(alu_out[1]), 
        .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), 
        .synch_enable(1'b1) );
  \**SEQGEN**  \alu_out_reg[0]  ( .clear(N8), .preset(1'b0), .next_state(X[0]), 
        .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(alu_out[0]), 
        .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), 
        .synch_enable(1'b1) );
  \**SEQGEN**  \reg_A_reg[7]  ( .clear(N8), .preset(1'b0), .next_state(
        inputA[7]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_A[7]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_A_reg[6]  ( .clear(N8), .preset(1'b0), .next_state(
        inputA[6]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_A[6]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_A_reg[5]  ( .clear(N8), .preset(1'b0), .next_state(
        inputA[5]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_A[5]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_A_reg[4]  ( .clear(N8), .preset(1'b0), .next_state(
        inputA[4]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_A[4]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_A_reg[3]  ( .clear(N8), .preset(1'b0), .next_state(
        inputA[3]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_A[3]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_A_reg[2]  ( .clear(N8), .preset(1'b0), .next_state(
        inputA[2]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_A[2]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_A_reg[1]  ( .clear(N8), .preset(1'b0), .next_state(
        inputA[1]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_A[1]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  \**SEQGEN**  \reg_A_reg[0]  ( .clear(N8), .preset(1'b0), .next_state(
        inputA[0]), .clocked_on(clk), .data_in(1'b0), .enable(1'b0), .Q(
        reg_A[0]), .synch_clear(1'b0), .synch_preset(1'b0), .synch_toggle(1'b0), .synch_enable(1'b1) );
  GTECH_AND2 C88 ( .A(N19), .B(N20), .Z(N22) );
  GTECH_AND2 C89 ( .A(N22), .B(N21), .Z(N23) );
  GTECH_OR2 C91 ( .A(reg_ins[2]), .B(reg_ins[1]), .Z(N24) );
  GTECH_OR2 C92 ( .A(N24), .B(N21), .Z(N25) );
  GTECH_OR2 C95 ( .A(reg_ins[2]), .B(N20), .Z(N27) );
  GTECH_OR2 C96 ( .A(N27), .B(reg_ins[0]), .Z(N28) );
  GTECH_OR2 C100 ( .A(reg_ins[2]), .B(N20), .Z(N30) );
  GTECH_OR2 C101 ( .A(N30), .B(N21), .Z(N31) );
  GTECH_OR2 C104 ( .A(N19), .B(reg_ins[1]), .Z(N33) );
  GTECH_OR2 C105 ( .A(N33), .B(reg_ins[0]), .Z(N34) );
  GTECH_AND2 C107 ( .A(reg_ins[2]), .B(reg_ins[0]), .Z(N36) );
  GTECH_AND2 C108 ( .A(reg_ins[2]), .B(reg_ins[1]), .Z(N37) );
  ADD_UNS_OP add_42 ( .A(reg_A), .B(reg_B), .Z({N46, N45, N44, N43, N42, N41, 
        N40, N39}) );
  SUB_UNS_OP sub_43 ( .A(reg_A), .B(reg_B), .Z({N54, N53, N52, N51, N50, N49, 
        N48, N47}) );
  SELECT_OP C156 ( .DATA1({N46, N45, N44, N43, N42, N41, N40, N39}), .DATA2({
        N54, N53, N52, N51, N50, N49, N48, N47}), .DATA3(inputB_inv), .DATA4({
        N55, N56, N57, N58, N59, N60, N61, N62}), .DATA5({N63, N64, N65, N66, 
        N67, N68, N69, N70}), .DATA6({N9, N10, N11, N12, N13, N14, N15, N16}), 
        .CONTROL1(N0), .CONTROL2(N1), .CONTROL3(N2), .CONTROL4(N3), .CONTROL5(
        N4), .CONTROL6(N5), .Z({N78, N77, N76, N75, N74, N73, N72, N71}) );
  GTECH_BUF B_0 ( .A(N23), .Z(N0) );
  GTECH_BUF B_1 ( .A(N26), .Z(N1) );
  GTECH_BUF B_2 ( .A(N29), .Z(N2) );
  GTECH_BUF B_3 ( .A(N32), .Z(N3) );
  GTECH_BUF B_4 ( .A(N35), .Z(N4) );
  GTECH_BUF B_5 ( .A(N38), .Z(N5) );
  SELECT_OP C157 ( .DATA1({N78, N77, N76, N75, N74, N73, N72, N71}), .DATA2({
        N9, N10, N11, N12, N13, N14, N15, N16}), .CONTROL1(N6), .CONTROL2(N7), 
        .Z(X) );
  GTECH_BUF B_6 ( .A(N17), .Z(N6) );
  GTECH_BUF B_7 ( .A(reg_ins[3]), .Z(N7) );
  GTECH_NOT I_0 ( .A(reset), .Z(N8) );
  GTECH_NOT I_1 ( .A(reg_B[7]), .Z(inputB_inv[7]) );
  GTECH_NOT I_2 ( .A(reg_B[6]), .Z(inputB_inv[6]) );
  GTECH_NOT I_3 ( .A(reg_B[5]), .Z(inputB_inv[5]) );
  GTECH_NOT I_4 ( .A(reg_B[4]), .Z(inputB_inv[4]) );
  GTECH_NOT I_5 ( .A(reg_B[3]), .Z(inputB_inv[3]) );
  GTECH_NOT I_6 ( .A(reg_B[2]), .Z(inputB_inv[2]) );
  GTECH_NOT I_7 ( .A(reg_B[1]), .Z(inputB_inv[1]) );
  GTECH_NOT I_8 ( .A(reg_B[0]), .Z(inputB_inv[0]) );
  GTECH_XOR2 C169 ( .A(reg_A[7]), .B(reg_B[7]), .Z(N9) );
  GTECH_XOR2 C170 ( .A(reg_A[6]), .B(reg_B[6]), .Z(N10) );
  GTECH_XOR2 C171 ( .A(reg_A[5]), .B(reg_B[5]), .Z(N11) );
  GTECH_XOR2 C172 ( .A(reg_A[4]), .B(reg_B[4]), .Z(N12) );
  GTECH_XOR2 C173 ( .A(reg_A[3]), .B(reg_B[3]), .Z(N13) );
  GTECH_XOR2 C174 ( .A(reg_A[2]), .B(reg_B[2]), .Z(N14) );
  GTECH_XOR2 C175 ( .A(reg_A[1]), .B(reg_B[1]), .Z(N15) );
  GTECH_XOR2 C176 ( .A(reg_A[0]), .B(reg_B[0]), .Z(N16) );
  GTECH_NOT I_9 ( .A(reg_ins[3]), .Z(N17) );
  GTECH_BUF B_8 ( .A(N17), .Z(N18) );
  GTECH_NOT I_10 ( .A(reg_ins[2]), .Z(N19) );
  GTECH_NOT I_11 ( .A(reg_ins[1]), .Z(N20) );
  GTECH_NOT I_12 ( .A(reg_ins[0]), .Z(N21) );
  GTECH_NOT I_13 ( .A(N25), .Z(N26) );
  GTECH_NOT I_14 ( .A(N28), .Z(N29) );
  GTECH_NOT I_15 ( .A(N31), .Z(N32) );
  GTECH_NOT I_16 ( .A(N34), .Z(N35) );
  GTECH_OR2 C193 ( .A(N36), .B(N37), .Z(N38) );
  GTECH_AND2 C200 ( .A(N18), .B(N23) );
  GTECH_AND2 C201 ( .A(N18), .B(N26) );
  GTECH_AND2 C202 ( .A(reg_A[7]), .B(reg_B[7]), .Z(N55) );
  GTECH_AND2 C203 ( .A(reg_A[6]), .B(reg_B[6]), .Z(N56) );
  GTECH_AND2 C204 ( .A(reg_A[5]), .B(reg_B[5]), .Z(N57) );
  GTECH_AND2 C205 ( .A(reg_A[4]), .B(reg_B[4]), .Z(N58) );
  GTECH_AND2 C206 ( .A(reg_A[3]), .B(reg_B[3]), .Z(N59) );
  GTECH_AND2 C207 ( .A(reg_A[2]), .B(reg_B[2]), .Z(N60) );
  GTECH_AND2 C208 ( .A(reg_A[1]), .B(reg_B[1]), .Z(N61) );
  GTECH_AND2 C209 ( .A(reg_A[0]), .B(reg_B[0]), .Z(N62) );
  GTECH_OR2 C210 ( .A(reg_A[7]), .B(reg_B[7]), .Z(N63) );
  GTECH_OR2 C211 ( .A(reg_A[6]), .B(reg_B[6]), .Z(N64) );
  GTECH_OR2 C212 ( .A(reg_A[5]), .B(reg_B[5]), .Z(N65) );
  GTECH_OR2 C213 ( .A(reg_A[4]), .B(reg_B[4]), .Z(N66) );
  GTECH_OR2 C214 ( .A(reg_A[3]), .B(reg_B[3]), .Z(N67) );
  GTECH_OR2 C215 ( .A(reg_A[2]), .B(reg_B[2]), .Z(N68) );
  GTECH_OR2 C216 ( .A(reg_A[1]), .B(reg_B[1]), .Z(N69) );
  GTECH_OR2 C217 ( .A(reg_A[0]), .B(reg_B[0]), .Z(N70) );
endmodule

