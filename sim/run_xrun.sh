#!/usr/bin/env bash
# Roda os testbenches no Cadence Xcelium (xrun).
#
#   sim/run_xrun.sh                  todos os testbenches e os 10 programas do processador
#   sim/run_xrun.sh tb_alu tb_pc     só os testbenches indicados
#   WAVES=1 sim/run_xrun.sh ...      também grava as formas de onda em sim/build/<teste>.shm
#
# Abrir as formas de onda: simvision sim/build/tb_processor_01_alu_reg.shm
# Logs de cada teste: sim/build/<teste>.log
set -u
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$RAIZ/sim/build"
mkdir -p "$BUILD"
cd "$RAIZ"

TBS="tb_adder tb_mux2 tb_mux4 tb_pc tb_pc_logic tb_alu tb_alu_ref tb_register_file
     tb_regfile_alu tb_data_memory tb_instruction_memory tb_imm_gen tb_alu_controller
     tb_controller tb_processor"
[ $# -gt 0 ] && TBS="$*"
falhas=0

# roda <nome do teste> <módulo do testbench> [plusargs...]
roda() {
  local nome=$1 tb=$2
  shift 2
  local extra=()
  if [ "${WAVES:-0}" = 1 ]; then
    printf 'database -open waves -shm -into %s -default\nprobe -create %s -all -depth all -memories\nrun\nexit\n' \
      "$BUILD/$nome.shm" "$tb" > "$BUILD/$nome.tcl"
    extra=(-access +rwc -input "$BUILD/$nome.tcl")
  fi
  # -sv: o tb_instruction_memory usa $fatal (SystemVerilog)
  xrun -sv -nocopyright -xmlibdirname "$BUILD/xcelium.d" -l "$BUILD/$nome.log" \
       -top "$tb" rtl/*.v "tb/$tb.v" "${extra[@]}" "$@" > /dev/null 2>&1

  local linha
  # tb_alu (vindo da main) imprime "ALL TESTS PASSED" / "<n> erros"; os demais, PASSOU / FALHOU
  linha=$(grep -E "PASSOU|FALHOU|ALL TESTS PASSED|^[0-9]+ erros" "$BUILD/$nome.log" | grep -v '\$display' | tail -1)
  if echo "$linha" | grep -qE "PASSOU|ALL TESTS PASSED" && ! grep -qE '^xrun: \*[EF],|^xmvlog: \*[EF],|^xmelab: \*[EF],|^xmsim: \*[EF],' "$BUILD/$nome.log"; then
    echo "  ok     $linha"
  else
    echo "  FALHA  ${linha:-$nome: sem resultado (veja sim/build/$nome.log)}"
    falhas=$((falhas + 1))
  fi
}

for tb in $TBS; do
  if [ "$tb" = tb_processor ]; then
    for hex in instructions/programs/*.hex; do
      prog=$(basename "$hex" .hex)
      roda "tb_processor_$prog" tb_processor "+TEST=$prog"
    done
  else
    roda "$tb" "$tb"
  fi
done

echo "----"
if [ "$falhas" -eq 0 ]; then echo "Todos os testes PASSARAM"; else echo "$falhas teste(s) com FALHA"; fi
exit "$falhas"
