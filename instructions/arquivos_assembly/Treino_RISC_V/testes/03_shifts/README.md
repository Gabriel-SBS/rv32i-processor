# 03 – Deslocamentos (shifts)

**Arquivos:** `03_shifts.s`, `03_shifts.hex` (81 instruções)
**Spec:** Seção 2.4, *Integer Computational Instructions*
**Instruções testadas:** `slli`, `srli`, `srai`, `sll`, `srl`, `sra`

## O que faz
Testa os deslocamentos lógicos (preenchem com zeros) e aritméticos (replicam o bit de sinal), com imediato (`shamt` de 5 bits) e com registrador. Segundo a spec, nos deslocamentos por registrador **só os 5 bits baixos de `rs2`** contam. Os subtestes 9, 10 e 13 usam 33, 63 e um valor negativo para verificar isso. Também valida o bit 30 da instrução, que diferencia `srli`/`srai` e `srl`/`sra`.

## Subtestes (`x30`)
| # | Operação | Esperado |
|---|---|---|
| 1 | `slli` 1 << 31 | `0x80000000` |
| 2 | `slli` 0x12345678 << 0 | `0x12345678` |
| 3 | `srli` 0x80000000 >> 31 | `1` |
| 4 | `srai` 0x80000000 >> 31 | `0xFFFFFFFF` |
| 5 | `srai` 0x40000000 >> 30 | `1` |
| 6 | `srli` 0xF0000000 >> 4 | `0x0F000000` |
| 7 | `srai` 0xF0000000 >> 4 | `0xFF000000` |
| 8 | `sll` 1 << 4 | `16` |
| 9 | `sll` 1 << 33 (usa 33 & 31 = 1) | `2` |
| 10 | `srl` 0x80000000 >> 63 (usa 31) | `1` |
| 11 | `sra` 0x80000000 >> 1 | `0xC0000000` |
| 12 | `sra` 0x7FFFFFFF >> 31 | `0` |
| 13 | `sll` 1 << 0xFFFFFFE4 (usa 4) | `16` |

## Estado final esperado
`x31 = 1`, `x30 = 13`, `x2 = 16`, `x3 = 0xFFFFFFE4`. Não usa memória de dados.
