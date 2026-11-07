# 10 – Teste de integração (algoritmos)

**Arquivos:** `10_algoritmo_final.s`, `10_algoritmo_final.hex` (118 instruções)
**Spec:** Seções 2.4, 2.5 e 2.6 (RV32I completo)
**Instruções usadas:** `add`, `addi`, `andi`, `srli`, `lui`, `lw`, `sw`, `lbu`, `sb`, `beq`, `bne`, `blt`, `bge`, `jal`, `jalr`

## O que faz
Combina as instruções em algoritmos reais, com laços aninhados, acesso a memória e chamada de sub-rotina. É o programa mais longo: executa cerca de 720 instruções. Nenhum algoritmo usa multiplicação ou divisão.

1. **Soma de vetor:** inicializa um vetor de 8 inteiros com sinal em `0x400` e soma seus elementos num laço.
2. **Fibonacci iterativo:** grava F(0) a F(20) em `0x500` e confere F(20) e F(10) com `lw` usando offset.
3. **Bubble sort:** ordena o vetor de `0x400` em ordem crescente (comparação com sinal, `bge`) com dois laços aninhados. Depois confere que `a[i] <= a[i+1]` para todo `i` e os valores dos extremos.
4. **Contagem de bits (popcount):** a sub-rotina chamada com `jal ra` conta os bits 1 de `a0` usando `andi`/`srli` e retorna com `ret`.
5. **strlen:** grava a string `"RISC-V"` byte a byte em `0x600`, terminada em zero, e mede seu comprimento com `lbu`/`beq`.

## Subtestes (`x30`)
| # | Algoritmo | Esperado |
|---|---|---|
| 1 | soma de `[5, −2, 17, 8, 0, 100, −30, 2]` | `100` |
| 2 | Fibonacci: F(20) e F(10) | `6765` e `55` |
| 3 | bubble sort | `[−30, −2, 0, 2, 5, 8, 17, 100]` |
| 4 | popcount(`0xF0F0F0F1`) | `17` |
| 5 | strlen(`"RISC-V"`) | `6` |

## Estado final esperado
Registradores: `x31 = 1`, `x30 = 5`, `x12 = 6`, `a0 (x10) = 17`.

Memória:

| Endereço | Conteúdo |
|---|---|
| `0x400`–`0x41C` | `0xFFFFFFE2` (−30), `0xFFFFFFFE` (−2), `0`, `2`, `5`, `8`, `17`, `100` |
| `0x500`–`0x550` | Fibonacci: `0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, …, 6765` (21 palavras) |
| `0x600` | bytes `52 49 53 43 2D 56 00` (`"RISC-V\0"`): palavras `0x43534952` e `0x0000562D` |

Para conferir: `python3 ../ferramentas/rv32i_sim.py 10_algoritmo_final.hex --regs --mem 0x400 8`.
