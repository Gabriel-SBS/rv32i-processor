# 07 – Load/Store de byte e meia-palavra

**Arquivos:** `07_load_store_byte_half.s`, `07_load_store_byte_half.hex` (94 instruções)
**Spec:** Seção 2.6, *Load and Store Instructions*
**Instruções testadas:** `lb`, `lbu`, `lh`, `lhu`, `sb`, `sh` (com `sw`/`lw` de apoio)

## O que faz
Grava a palavra `0x80FF7F01` em `0x400` e lê seus bytes e meias-palavras. Como o RISC-V é **little-endian**, os bytes na memória ficam assim:

| `0x400` | `0x401` | `0x402` | `0x403` |
|---|---|---|---|
| `01` | `7F` | `FF` | `80` |

O programa testa:
- **extensão de sinal** (`lb`, `lh`) e **extensão com zeros** (`lbu`, `lhu`) sobre os mesmos dados;
- que `sb` e `sh` alteram **só** 1 e 2 bytes, gravando apenas os bits baixos do registrador, sem afetar os bytes vizinhos;
- um `sb` com offset negativo.

Todos os acessos de meia-palavra são alinhados em 2 bytes.

## Subtestes (`x30`)
| # | Operação | Esperado |
|---|---|---|
| 1 | `lb 0(0x400)` → byte `01` | `0x00000001` |
| 2 | `lb 1(0x400)` → byte `7F` | `0x0000007F` |
| 3 | `lb 2(0x400)` → byte `FF` | `0xFFFFFFFF` |
| 4 | `lbu 2(0x400)` → byte `FF` | `0x000000FF` |
| 5 | `lb 3(0x400)` → byte `80` | `0xFFFFFF80` |
| 6 | `lbu 3(0x400)` → byte `80` | `0x00000080` |
| 7 | `lh 0(0x400)` → `7F01` | `0x00007F01` |
| 8 | `lh 2(0x400)` → `80FF` | `0xFFFF80FF` |
| 9 | `lhu 2(0x400)` → `80FF` | `0x000080FF` |
| 10 | `0x11223344` em `0x404`, `sb 0xAA` em `0x405` | palavra `0x1122AA44` |
| 11 | `sh 0xBEEF` em `0x406` | palavra `0xBEEFAA44` |
| 12 | `sb 0x123456CC` em `0x404` (só `CC`) | palavra `0xBEEFAACC` |
| 13 | `sh 0xFFFF8001` em `0x400`, depois `lh` | palavra `0x80FF8001`, `lh` = `0xFFFF8001` |
| 14 | `sb 0x5A` em `-1(0x408)` = `0x407` | palavra `0x5AEFAACC` |

## Estado final esperado
Registradores: `x31 = 1`, `x30 = 14`, `x3 = 0x5AEFAACC`.

Memória:

| Endereço | Valor |
|---|---|
| `0x400` | `0x80FF8001` |
| `0x404` | `0x5AEFAACC` |
