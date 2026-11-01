# 02 – ALU com imediato

**Arquivos:** `02_alu_imm.s`, `02_alu_imm.hex` (68 instruções)
**Spec:** Seção 2.4, *Integer Register-Immediate Instructions*
**Instruções testadas:** `addi`, `andi`, `ori`, `xori`

## O que faz
Testa as instruções tipo I com imediato de 12 bits. O ponto principal é a **extensão de sinal** do imediato: o bit 11 é replicado até o bit 31 antes da operação. Por isso `andi x, -16` usa a máscara `0xFFFFFFF0` e `xori x, -1` funciona como NOT. Também testa os limites da faixa (2047 e -2048) e o "nop" `addi x0, x0, 5`.

## Subtestes (`x30`)
| # | Operação | Esperado |
|---|---|---|
| 1 | `addi x1, x0, 2047` | `0x000007FF` |
| 2 | `addi x1, x0, -2048` | `0xFFFFF800` |
| 3 | `addi` 100 + (−1) | `99` |
| 4 | `addi` 0xFFFFFFFF + 1 (wrap) | `0` |
| 5 | `andi` 0x12345678 & 0xFF | `0x78` |
| 6 | `andi` 0x12345678 & −1 | `0x12345678` |
| 7 | `andi` 0x12345678 & −16 | `0x12345670` |
| 8 | `ori` 0x12345600 \| 0xFF | `0x123456FF` |
| 9 | `ori` 0x12345600 \| −2048 | `0xFFFFFE00` |
| 10 | `xori` 0x12345678 ^ −1 (NOT) | `0xEDCBA987` |
| 11 | `xori` 0x55555555 ^ 0x555 | `0x55555000` |
| 12 | `addi x0, x0, 5`: x0 continua 0 | `x0 = 0` |

## Estado final esperado
`x31 = 1`, `x30 = 12`, `x2 = 0`, `x1 = 0x55555555`. Não usa memória de dados.
