#!/usr/bin/env bash
# Monta todos os programas de teste (.s -> .hex) e confere cada um no
# simulador de referência. Uso: ./gerar_todos.sh   (de qualquer diretório)
set -u
FERR="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(dirname "$FERR")"
falhas=0

for dir in "$RAIZ"/[0-9][0-9]_*/; do
    nome="$(basename "$dir")"
    src="$dir$nome.s"
    hex="$dir$nome.hex"
    python3 "$FERR/rv32i_asm.py" "$src" -o "$hex" > /dev/null || { echo "$nome: ERRO DE MONTAGEM"; falhas=$((falhas + 1)); continue; }
    python3 "$FERR/rv32i_sim.py" "$hex" | sed "s|$RAIZ/||" || falhas=$((falhas + 1))
done

echo "----"
if [ "$falhas" -eq 0 ]; then echo "Todos os programas PASSARAM"; else echo "$falhas programa(s) com FALHA"; fi
exit "$falhas"
