# 09 – JAL e JALR (saltos e sub-rotinas)

**Arquivos:** `09_jal_jalr.s`, `09_jal_jalr.hex` (71 instruções)
**Spec:** Seção 2.5, *Control Transfer Instructions – Unconditional Jumps*
**Instruções testadas:** `jal`, `jalr`

## O que faz
Testa as duas instruções de salto incondicional:
- **`jal rd, rótulo`** salta para `PC + offset` (21 bits com sinal) e grava `PC + 4` em `rd`.
- **`jalr rd, off(rs1)`** salta para `(rs1 + off)` com o **bit 0 zerado** e grava `PC + 4` em `rd`.

O programa testa chamada e retorno de sub-rotina (`jal ra` / `jalr x0, 0(ra)`), o valor exato salvo em `ra`, o `j` (`jal x0`) sem link e o `jalr` com offset. Testa também o zeramento do bit 0 com um endereço ímpar e o caso `rd == rs1`: a spec exige que o alvo use o valor **antigo** de `rs1`. Por fim, testa uma chamada aninhada, que salva `ra` em `x20`, e um salto para trás.

As sub-rotinas ficam depois do laço final.

## Subtestes (`x30`)
| # | Caso | Esperado |
|---|---|---|
| 1 | `jal ra, func1` (func1 faz `x5 = 0x11` e retorna) | `x5 = 0x11` |
| 2 | `ra` após o subteste 1 | endereço de `volta1` (PC do `jal` + 4) |
| 3 | `j pula3` pula `li x6, 0x333` | `x6 = 0` |
| 4 | `jalr ra, 8(x7)` com `x7 = alvo4 − 8` | `x8 = 0x44` |
| 5 | `jalr ra, 0(x7)` com `x7 = alvo5 + 1` (ímpar) | `x8 = 0x55` |
| 6 | `jalr x7, 0(x7)` (rd == rs1) | salta para `alvo6`, `x7 = volta6` |
| 7 | `externa` chama `interna` (aninhado) | `x9 = 3` |
| 8 | `j frente` → `j tras` (para trás) → `j depois8` | `x10 = 2` |

## Estado final esperado
`x31 = 1`, `x30 = 8`, `x5 = 0x11`, `x8 = 0x55`, `x9 = 3`, `x10 = 2`. Não usa memória de dados.
