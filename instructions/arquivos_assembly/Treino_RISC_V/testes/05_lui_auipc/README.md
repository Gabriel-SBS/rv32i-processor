# 05 – LUI e AUIPC (tipo U)

**Arquivos:** `05_lui_auipc.s`, `05_lui_auipc.hex` (61 instruções)
**Spec:** Seção 2.4, *Integer Computational Instructions* (LUI e AUIPC)
**Instruções testadas:** `lui`, `auipc` (com `addi` para completar constantes)

## O que faz
- **`lui`** coloca o imediato de 20 bits nos bits 31:12 de `rd` e zera os 12 bits baixos.
- **`auipc`** soma esse mesmo valor ao **PC da própria instrução**.

O programa mostra como montar uma constante de 32 bits com `lui` + `addi`. Se o bit 11 da parte baixa é 1, o `addi` soma um valor negativo, então o `lui` precisa receber a parte alta + 1. Exemplo: `0xDEADBEEF` = `lui 0xDEADC` + `addi -273`. O programa também confere endereços relativos ao PC, com deslocamento positivo, negativo e via a pseudo `la` (`auipc` + `addi`).

## Subtestes (`x30`)
| # | Operação | Esperado |
|---|---|---|
| 1 | `lui x1, 0x12345` | `0x12345000` |
| 2 | `lui x1, 0xFFFFF` | `0xFFFFF000` |
| 3 | `lui 0x12345` + `addi 0x678` | `0x12345678` |
| 4 | `lui 0xDEADC` + `addi -273` | `0xDEADBEEF` |
| 5 | `lui x0, 0xABCDE`: x0 continua 0 | `x0 = 0` |
| 6 | `auipc x1, 0` em `aqui` | endereço de `aqui` (`0x78`) |
| 7 | `auipc x1, 1` em `aqui2` | `aqui2 + 0x1000` |
| 8 | `auipc x1, 0xFFFFF` em `aqui3` | `aqui3 − 0x1000` (wrap) |
| 9 | `la x1, alvo` | endereço de `alvo` |

Os endereços exatos aparecem com `python3 ../ferramentas/rv32i_asm.py 05_lui_auipc.s --lst`.

## Estado final esperado
`x31 = 1`, `x30 = 9`, `x1 = x29 =` endereço do rótulo `alvo` (`0xF0`). Não usa memória de dados.
