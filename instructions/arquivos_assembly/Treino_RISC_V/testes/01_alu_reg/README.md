# 01 – ALU registrador-registrador

**Arquivos:** `01_alu_reg.s`, `01_alu_reg.hex` (74 instruções)
**Spec:** Seção 2.4, *Integer Register-Register Operations*
**Instruções testadas:** `add`, `sub`, `and`, `or`, `xor`

## O que faz
Testa as operações aritméticas e lógicas do tipo R. Os operandos são carregados com `li`, a operação é executada e o resultado é comparado com o valor esperado. Também verifica que o overflow não gera exceção (a spec determina que o resultado simplesmente "dá a volta"), que escrever em `x0` não tem efeito e que `rd` pode ser o mesmo registrador das fontes.

## Subtestes (`x30`)
| # | Operação | Esperado |
|---|---|---|
| 1 | `add` 5 + 7 | `12` |
| 2 | `add` -3 + 10 | `7` |
| 3 | `add` 0x7FFFFFFF + 1 (overflow) | `0x80000000` |
| 4 | `sub` 10 − 3 | `7` |
| 5 | `sub` 3 − 10 | `-7` (`0xFFFFFFF9`) |
| 6 | `sub` 0 − 0x80000000 | `0x80000000` |
| 7 | `and` 0xF0F0F0F0 & 0x0FF00FF0 | `0x00F000F0` |
| 8 | `or` 0xF0F0F0F0 \| 0x0FF00FF0 | `0xFFF0FFF0` |
| 9 | `xor` 0xF0F0F0F0 ^ 0x0FF00FF0 | `0xFF00FF00` |
| 10 | `xor` x1, x1 | `0` |
| 11 | `add x0, x1, x2`: x0 continua 0 | `x0 = 0` |
| 12 | `add x4, x4, x4` com x4 = 21 | `42` |

## Estado final esperado
`x31 = 1`, `x30 = 12`, `x4 = 42` (`0x2A`), `x3 = 0`, `x0 = 0`. Não usa memória de dados.
