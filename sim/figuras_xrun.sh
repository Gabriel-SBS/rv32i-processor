#!/usr/bin/env bash
# Gera as formas de onda das figuras do relatório.
#   sim/figuras_xrun.sh              roda todas as figuras
#   sim/figuras_xrun.sh view fig04   abre a figura 4 no ponto exato
set -u
cd "$(dirname "$0")/.."
BUILD=sim/build/figuras
mkdir -p "$BUILD" relatorio/figuras

DP=tb_processor.dut.u_datapath

FIGURAS=(
  "fig01|01_alu_reg|#tb_processor.rst_n == 1'b1|fim do reset"
  "fig02|01_alu_reg|#$DP.opcode == 7'b0110011 && #$DP.funct7 == 7'b0100000|SUB (tipo R)"
  "fig03|02_alu_imm|#$DP.opcode == 7'b0010011 && #$DP.imm_ext[31] == 1'b1|ADDI com imediato negativo"
  "fig04|05_lui_auipc|#$DP.opcode == 7'b0010111|AUIPC"
  "fig05|07_load_store_byte_half|#$DP.opcode == 7'b0100011 && #$DP.funct3 == 3'b000|SB"
  "fig06|07_load_store_byte_half|#$DP.opcode == 7'b0000011 && #$DP.funct3 == 3'b000|LB"
  "fig07|08_branches|#$DP.opcode == 7'b1100011 && #tb_processor.dut.branch_taken == 1'b1|desvio tomado"
  "fig08|08_branches|#$DP.opcode == 7'b1100011 && #tb_processor.dut.branch_taken == 1'b0|desvio não tomado"
  "fig09|09_jal_jalr|#$DP.opcode == 7'b1101111 && #$DP.rd != 5'd0|JAL"
  "fig10|09_jal_jalr|#$DP.opcode == 7'b1100111|JALR"
  "fig11|10_algoritmo_final|#$DP.instr == 32'h0000006f|fim do programa 10"
)

if [ "${1:-}" = view ] && [ -n "${2:-}" ]; then
  [ -f "$BUILD/$2.t" ] || { echo "Rode primeiro: sim/figuras_xrun.sh"; exit 1; }
  echo "Abrindo $2 em $(cat "$BUILD/$2.t") ns..."
  SHM="$BUILD/$2.shm" CURSOR=$(cat "$BUILD/$2.t") LIBGL_ALWAYS_SOFTWARE=1 \
    simvision -input sim/simvision_processor.tcl
  exit 0
fi

for f in "${FIGURAS[@]}"; do
  IFS='|' read -r nome prog cond desc <<< "$f"
  echo "-> $nome: $desc ($prog)"
  rm -rf "$BUILD/$nome.shm"
  # para no meio do ciclo (clk = 0), quando os sinais já estão estáveis
  cat > "$BUILD/$nome.tcl" <<EOF
database -open waves -shm -into $BUILD/$nome.shm -default
probe -create tb_processor -all -depth all -memories
stop -create -name parada -condition {#tb_processor.clk == 1'b0 && $cond}
run
set fd [open $BUILD/$nome.t w]; puts \$fd [time -nounit ns]; close \$fd
puts "@@ t=[time -nounit ns] ns  pc=[value %h $DP.pc]  instr=[value %h $DP.instr]  result=[value %h $DP.result]"
stop -delete parada
run 30ns
exit
EOF
  xrun -q -sv -access +rwc -xmlibdirname "$BUILD/xcelium.d" -l "$BUILD/$nome.log" \
       -top tb_processor rtl/*.v tb/tb_processor.v +TEST="$prog" -input "$BUILD/$nome.tcl" > /dev/null 2>&1
  grep '^@@' "$BUILD/$nome.log" | sed 's/^@@/  /'
done

echo
echo "Para abrir cada figura e salvar a imagem em relatorio/figuras/:"
for f in "${FIGURAS[@]}"; do echo "  sim/figuras_xrun.sh view ${f%%|*}"; done
