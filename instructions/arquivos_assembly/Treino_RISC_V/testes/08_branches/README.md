# 08 – Desvios condicionais

**Arquivos:** `08_branches.s`, `08_branches.hex` (80 instruções)
**Spec:** Seção 2.5, *Control Transfer Instructions – Conditional Branches*
**Instruções testadas:** `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`

## O que faz
Testa cada desvio nas duas situações, **tomado** e **não tomado**, usando `x4 = −1` (`0xFFFFFFFF`) e `x5 = 1` para distinguir a comparação com sinal (`blt`/`bge`) da comparação sem sinal (`bltu`/`bgeu`). Também testa:
- que o desvio não tomado executa a próxima instrução e que o tomado a pula;
- desvios **para trás**, com deslocamento negativo, em três laços.

O alvo de um desvio é `PC + offset`, com offset de 13 bits com sinal (múltiplo de 2).

Padrões usados:
- **tomado:** `bXX ..., okN` / `j falha` / `okN:`. Se o desvio não acontecer, cai em `falha`.
- **não tomado:** `bXX ..., falha`. Se o desvio acontecer, cai em `falha`.

## Subtestes (`x30`)
| # | Caso | Resultado correto |
|---|---|---|
| 1 | `beq` 5 == 5 | tomado |
| 2 | `beq` 5 == 6 | não tomado |
| 3 | `bne` 5 != 6 | tomado |
| 4 | `bne` 5 != 5 | não tomado |
| 5 | `blt` −1 < 1 | tomado |
| 6 | `blt` 5 < 5 | não tomado |
| 7 | `bge` 1 >= −1 | tomado |
| 8 | `bge` 5 >= 5 | tomado |
| 9 | `bge` −1 >= 1 | não tomado |
| 10 | `bltu` 0xFFFFFFFF < 1 | não tomado |
| 11 | `bltu` 1 < 0xFFFFFFFF | tomado |
| 12 | `bgeu` 0xFFFFFFFF >= 1 | tomado |
| 13 | `bgeu` 1 >= 0xFFFFFFFF | não tomado |
| 14 | não tomado executa a instrução seguinte | `x6 = 1` |
| 15 | tomado pula a instrução seguinte | `x6 = 0` |
| 16 | laço com `bne` para trás (5 iterações) | `x7 = 5` |
| 17 | laço com `blt` para trás: soma 0..9 | `x7 = 45` |
| 18 | laço com `bgeu` para trás (3 iterações) | `x7 = 3` |

## Estado final esperado
`x31 = 1`, `x30 = 18`, `x6 = 0`, `x7 = 3`. Não usa memória de dados.
