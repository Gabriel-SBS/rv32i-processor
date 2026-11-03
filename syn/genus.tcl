# Síntese do processador no Cadence Genus.
#
#   cd syn && genus -files genus.tcl -log build/genus
#
# LIB_PATH/LIB_NAME apontam para a biblioteca de exemplo que vem com o Genus
# (tutorial.lib: 12 células, sem tecnologia real). Troque pela biblioteca do PDK
# quando ela estiver disponível; os números de área e de tempo só valem para a
# biblioteca usada.
#
# As memórias de instruções e de dados ficam como caixas-pretas: num chip elas
# seriam macros de SRAM/ROM, e a de instruções é carregada com $readmemh, que a
# síntese ignora. O resultado mede o núcleo (banco de registradores, ULA,
# controle, PC e gerador de imediatos).

if {[info exists env(LIB_PATH)]} { set lib_path $env(LIB_PATH) } else { set lib_path /cadence/GENUS25.13/share/synth/tutorials/tech }
if {[info exists env(LIB_NAME)]} { set lib_name $env(LIB_NAME) } else { set lib_name tutorial.lib }
if {[info exists env(PERIODO)]}  { set periodo  $env(PERIODO)  } else { set periodo 20.0 }

file mkdir build

set_db init_lib_search_path $lib_path
set_db library $lib_name
set_db init_hdl_search_path ../rtl
set_db hdl_error_on_blackbox false
set_db information_level 2

read_hdl -v2001 {
  adder.v alu.v alu_controller.v controller.v datapath.v imm_gen.v
  mux2.v mux4.v pc.v pc_logic.v processor.v reg_bank.v
}
elaborate processor
check_design -unresolved > build/check_design.rpt

create_clock -name clk -period $periodo [get_ports clk]
set_output_delay 0 -clock clk [all_outputs]

syn_generic
syn_map
syn_opt

report_area           > build/area.rpt
report_gates          > build/gates.rpt
report_timing -nworst 1 > build/timing.rpt
report_qor            > build/qor.rpt
check_design -all     > build/check_design_final.rpt
write_hdl             > build/processor_netlist.v

puts "LATCHES: [llength [get_db insts -if {.is_latch}]]"
puts "FLOPS:   [llength [get_db insts -if {.is_flop}]]"
exit
