# 04 – Comparações (set less than)

**Arquivos:** `04_comparacoes.s`, `04_comparacoes.hex` (55 instruções)
**Spec:** Seção 2.4, *Integer Computational Instructions*
**Instruções testadas:** `slt`, `sltu`, `slti`, `sltiu`

## O que faz
Testa as instruções que escrevem 1 em `rd` quando `rs1 < rs2` (ou `rs1 < imediato`) e 0 caso contrário. O mesmo padrão de bits dá resultados opostos conforme a comparação: `0xFFFFFFFF` vale −1 com sinal, mas é o maior número sem sinal. Também testa os idiomas citados na spec: `sltiu rd, rs, 1` (equivale a `seqz`) e `sltu rd, x0, rs` (equivale a `snez`). Testa ainda que o imediato de `sltiu` é estendido com sinal antes da comparação sem sinal (−1 vira `0xFFFFFFFF`).

## Subtestes (`x30`)
| # | Operação | Esperado |
|---|---|---|
| 1 | `slt` −1 < 1 | `1` |
| 2 | `sltu` 0xFFFFFFFF < 1 | `0` |
| 3 | `slt` 1 < −1 | `0` |
| 4 | `sltu` 1 < 0xFFFFFFFF | `1` |
| 5 | `slt` 5 < 5 | `0` |
| 6 | `slti` −1 < 0 | `1` |
| 7 | `slti` 5 < −3 | `0` |
| 8 | `sltiu` 0 < 1 (seqz de 0) | `1` |
| 9 | `sltiu` 7 < 1 (seqz de 7) | `0` |
| 10 | `sltiu` 1 < −1 (0xFFFFFFFF) | `1` |
| 11 | `slt` 0x80000000 < 0x7FFFFFFF | `1` |
| 12 | `sltu` 0x80000000 < 0x7FFFFFFF | `0` |
| 13 | `sltu` 0 < 7 (snez de 7) | `1` |

## Estado final esperado
`x31 = 1`, `x30 = 13`, `x3 = 1`. Não usa memória de dados.
