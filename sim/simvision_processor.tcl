# Abre as formas de onda do tb_processor no SimVision com os sinais agrupados.
#
#   WAVES=1 sim/run_xrun.sh tb_processor
#   SHM=sim/build/tb_processor_05_lui_auipc.shm simvision -input sim/simvision_processor.tcl
#
# Sem SHM, abre o programa 01. Com CURSOR=<tempo em ns>, posiciona o cursor.

if {[info exists env(SHM)]} { set shm $env(SHM) } else { set shm sim/build/tb_processor_01_alu_reg.shm }
database require waves -search [list $shm]

set top waves::tb_processor
set dp  $top.dut.u_datapath

window new WaveWindow -name "Processador RV32I"
waveform using "Processador RV32I"

proc grupo {nome sinais} {
  group new -name $nome -overlay 0
  group using $nome
  group clear 0 end
  foreach s $sinais { group insert $s }
  waveform add -groups [list $nome]
}

grupo "Clock e reset"   [list $top.clk $top.rst_n]
grupo "Busca"           [list $dp.pc $dp.instr $dp.pc_next $dp.pc_plus4 $dp.pc_target]
grupo "Decodificacao"   [list $dp.opcode $dp.funct3 $dp.funct7 $dp.rd $dp.rs1 $dp.rs2 $dp.imm_ext]
grupo "Controle"        [list $dp.PC_sel $dp.REG_sel $dp.ALU_Control $dp.rs1_sel $dp.rs2_sel $dp.we_reg $dp.we_mem]
grupo "Execucao (ULA)"  [list $dp.rs1_o $dp.rs2_o $dp.src_a $dp.src_b $dp.result]
grupo "Memoria e WB"    [list $dp.u_data_memory.addr $dp.mem_o $dp.write_back_result]
grupo "Status do teste" [list $dp.u_reg_bank.mem\[30\] $dp.u_reg_bank.mem\[31\]]

# barramentos em hexadecimal (sinais de 1 bit não aceitam radix)
foreach id [waveform find -name *] { catch {waveform format $id -radix %x} }

if {[info exists env(CURSOR)]} {
  cursor set -using TimeA -time "$env(CURSOR)ns"
  waveform xview limits [expr {$env(CURSOR) - 60}]ns [expr {$env(CURSOR) + 40}]ns
} else {
  waveform xview limits 0 400ns
}
