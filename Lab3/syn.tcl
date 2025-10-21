set company "CIC"
set designer "Student"
set search_path {/home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/SynopsysDC/lib \
    /home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/SynopsysDC/db \
    $search_path}
set link_library "typical.db slow.db fast.db dw_foundation.sldb"
set target_library "typical.db slow.db fast.db"
set symbol_library "generic.sdb"
set synthetic_library "dw_foundation.sldb"

read_file -format verilog {./Lab3_alu.v}

# write -format verilog -hierarchy -output ALU_GTECH.v

create_clock -name "clk" -period 10 -waveform {"0" "5"} {"clk"}
set_dont_touch_network [find clock clk]
set_fix_hold clk

set_operating_conditions "typical" -library "typical"
set_wire_load_model -name "ForQA" -library "typical"
set_wire_load_mode "segmented"

set_input_delay -clock clk 2.5 inputA[*] 
set_input_delay -clock clk 3.8 inputB[*] 
set_input_delay -clock clk 4.5 instruction[*]
set_input_delay -clock clk 5.2 reset
set_output_delay -clock clk 8 alu_out[*]

set_boundary_optimization "*"
set_fix_multiple_port_nets -all -buffer_constant
set_max_area 0
set_max_fanout 8 ALU
set_max_transition 1 ALU

check_design

compile -map_effort medium

report_timing -path full -delay max -max_paths 1 -nworst 1 > ALU.timing
report_power > ALU.power
report_area -nosplit > ALU.area

write -hierarchy -format ddc
write_sdc ALU.sdc
write_sdf -version 2.1 ALU.sdf
write -format verilog -hierarchy -output ALU_syn.v

exit