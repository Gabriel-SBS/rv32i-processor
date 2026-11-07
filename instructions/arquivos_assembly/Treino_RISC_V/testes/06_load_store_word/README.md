# 06 – Load/Store de palavra

**Arquivos:** `06_load_store_word.s`, `06_load_store_word.hex` (70 instruções)
**Spec:** Seção 2.6, *Load and Store Instructions*
**Instruções testadas:** `sw`, `lw`

## O que faz
Testa a escrita e a leitura de palavras de 32 bits. O endereço efetivo é `rs1 + offset`, com offset de 12 bits **com sinal**. Os subtestes verificam:
- offsets positivos, negativos e o maior offset alinhado (2044);
- que escrever numa posição não altera as vizinhas;
- que `lw` em `x0` é descartado e que `sw x0` grava zero.

O subteste 6 copia um vetor de 4 palavras com um laço (`lw`/`sw`/`addi`/`bne`) e soma o destino.

Todos os acessos são alinhados em 4 bytes.

## Subtestes (`x30`)
| # | Operação | Esperado |
|---|---|---|
| 1 | `sw`/`lw` em `0(0x400)` | `0x12345678` |
| 2 | `sw`/`lw` em `4(0x400)` | `0xDEADBEEF` |
| 3 | releitura de `0x400` após o subteste 2 | `0x12345678` (sem mudança) |
| 4 | `sw -8(0x410)` lido com `lw 8(0x400)` | `0xCAFEF00D` |
| 5 | `sw`/`lw` em `2044(x0)` = `0x7FC` | `0x0BADC0DE` |
| 6 | cópia `0x420..0x42C` → `0x440..0x44C` e soma | `100` |
| 7 | `lw x0, ...`: x0 continua 0 | `x0 = 0` |
| 8 | `sw x0, 0(0x400)` e releitura | `0` |

## Estado final esperado
Registradores: `x31 = 1`, `x30 = 8`, `x14 = 0`, `x1 = 100`.

Memória:

| Endereço | Valor |
|---|---|
| `0x400` | `0x00000000` |
| `0x404` | `0xDEADBEEF` |
| `0x408` | `0xCAFEF00D` |
| `0x420`–`0x42C` | `10, 20, 30, 40` |
| `0x440`–`0x44C` | `10, 20, 30, 40` |
| `0x7FC` | `0x0BADC0DE` |

Para conferir: `python3 ../ferramentas/rv32i_sim.py 06_load_store_word.hex --mem 0x400 20`.
