#!/usr/bin/env bash
# Roda os testbenches no Icarus Verilog (iverilog + vvp), para quando não há xrun.
#
#   sim/run_iverilog.sh                  todos os testbenches e os 10 programas do processador
#   sim/run_iverilog.sh tb_alu tb_pc     só os testbenches indicados
#
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
  # -g2012: o tb_instruction_memory usa $fatal
  if ! iverilog -g2012 -s "$tb" -o "$BUILD/$tb.vvp" rtl/*.v "tb/$tb.v" > "$BUILD/$nome.log" 2>&1; then
    echo "  FALHA  $nome: não compilou (veja sim/build/$nome.log)"
    falhas=$((falhas + 1))
    return
  fi
  vvp -n "$BUILD/$tb.vvp" "$@" >> "$BUILD/$nome.log" 2>&1

  local linha
  linha=$(grep -E "PASSOU|FALHOU|ALL TESTS PASSED|^[0-9]+ erros" "$BUILD/$nome.log" | tail -1)
  if echo "$linha" | grep -qE "PASSOU|ALL TESTS PASSED" && ! grep -qE "FATAL|ERROR:" "$BUILD/$nome.log"; then
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
