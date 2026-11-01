# Programas de teste RV32I

Bateria de 10 programas em Assembly RISC-V de 32 bits (RV32I) para validar um processador, por exemplo uma implementação em Verilog. Cada programa vem com o arquivo `.hex` pronto para carregar na memória de instruções.

- **Base:** `riscv-spec.pdf` (*The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA*, versão 20190608), capítulo 2 "RV32I Base Integer Instruction Set" e capítulo 24 (tabelas de codificação).
- **Escopo:** as 37 instruções de usuário do RV32I. Nenhum programa usa a extensão M (`mul`, `div`, `rem`), nem `ecall`, `ebreak`, `fence` ou CSRs.

## Estrutura

```
testes/
├── README.md                    este arquivo
├── ferramentas/
│   ├── rv32i_asm.py             montador .s -> .hex
│   ├── rv32i_sim.py             simulador de referência
│   └── gerar_todos.sh           monta e confere todos os programas
├── 01_alu_reg/                  add, sub, and, or, xor
├── 02_alu_imm/                  addi, andi, ori, xori
├── 03_shifts/                   sll, srl, sra, slli, srli, srai
├── 04_comparacoes/              slt, sltu, slti, sltiu
├── 05_lui_auipc/                lui, auipc
├── 06_load_store_word/          lw, sw
├── 07_load_store_byte_half/     lb, lbu, lh, lhu, sb, sh
├── 08_branches/                 beq, bne, blt, bge, bltu, bgeu
├── 09_jal_jalr/                 jal, jalr
└── 10_algoritmo_final/          integração (algoritmos)
```

Cada pasta contém:
- `NN_nome.s`: o código-fonte comentado;
- `NN_nome.hex`: o código de máquina;
- `README.md`: o que o programa testa, a lista de subtestes e o estado final esperado.

A ordem sugerida é de 01 a 10: cada programa depende de poucas instruções já testadas nos anteriores.

## Convenções comuns a todos os programas

| Registrador | Significado |
|---|---|
| `x30` | Número do subteste em execução (1, 2, 3, ...) |
| `x31` | Resultado: **`1` = todos passaram**, **`0xBAD` = falha** (então `x30` indica qual subteste falhou) |
| `x29`, `x28` | Valores esperados usados nas comparações |

- **Início:** endereço `0x00000000`.
- **Fim:** todo programa termina no laço `fim: j fim`, codificado como `0000006F` (`jal x0, 0`). Quando o PC fica parado nessa instrução, basta ler `x31`.
- **Verificação:** cada subteste compara o resultado com o valor esperado usando `bne ..., falha`. Por isso `bne`, `jal` e `addi`/`lui` (usados pela pseudo `li`) são pré-requisitos de todos os programas.
- **Memória de dados:** os programas 06, 07 e 10 usam a região `0x400` a `0x7FF`. O processador precisa de **pelo menos 2 KiB** de memória (o código ocupa menos de `0x400` bytes). Os testes supõem memória **unificada** (instruções e dados no mesmo espaço de endereços), mas só os endereços ≥ `0x400` são escritos.
- **Endianness:** little-endian, como define a spec (relevante para o programa 07).

## Formato do `.hex`

Uma instrução de 32 bits por linha, com 8 dígitos hexadecimais, sem prefixo, sem endereço e sem comentários:

```
00000F93
00100F13
00500093
...
```

Linha *N* (contando de 0) = instrução no endereço `4*N`. O formato é compatível com `$readmemh` em uma memória de palavras de 32 bits:

```verilog
reg [31:0] mem [0:511];                    // 2 KiB
initial $readmemh("01_alu_reg.hex", mem);
wire [31:0] instr = mem[pc[31:2]];         // índice = PC / 4
```

## Mapa de cobertura (instrução × programa)

| Instrução | Programas | | Instrução | Programas |
|---|---|---|---|---|
| `lui` | 05 (e em todos via `li`) | | `addi` | 02 (e em todos via `li`) |
| `auipc` | 05 | | `slti` | 04 |
| `jal` | 09, 10 (e em todos via `j`) | | `sltiu` | 04 |
| `jalr` | 09, 10 | | `xori` | 02 |
| `beq` | 08, 10 | | `ori` | 02 |
| `bne` | 08 (e em todos na verificação) | | `andi` | 02, 10 |
| `blt` | 08, 10 | | `slli` | 03 |
| `bge` | 08, 10 | | `srli` | 03, 10 |
| `bltu` | 08 | | `srai` | 03 |
| `bgeu` | 08 | | `add` | 01, 05, 06, 08, 10 |
| `lb` | 07 | | `sub` | 01 |
| `lh` | 07 | | `sll` | 03 |
| `lw` | 06, 07, 10 | | `slt` | 04 |
| `lbu` | 07, 10 | | `sltu` | 04 |
| `lhu` | 07 | | `xor` | 01 |
| `sb` | 07, 10 | | `srl` | 03 |
| `sh` | 07 | | `sra` | 03 |
| `sw` | 06, 07, 10 | | `or` | 01 |
| | | | `and` | 01 |

As 37 instruções do RV32I aparecem em pelo menos um programa.

## Ferramentas

Não há toolchain RISC-V instalada, então os `.hex` são gerados por um montador próprio em Python (sem dependências).

```bash
# Autoteste do montador (compara com codificações conhecidas)
python3 ferramentas/rv32i_asm.py --teste

# Montar um programa (--lst mostra endereço, código e fonte)
python3 ferramentas/rv32i_asm.py 01_alu_reg/01_alu_reg.s --lst

# Executar no simulador de referência
python3 ferramentas/rv32i_sim.py 01_alu_reg/01_alu_reg.hex --regs
python3 ferramentas/rv32i_sim.py 06_load_store_word/06_load_store_word.hex --mem 0x400 8

# Regenerar todos os .hex e conferir todos os programas
./ferramentas/gerar_todos.sh
```

Pseudoinstruções aceitas pelo montador: `nop`, `li`, `la`, `mv`, `not`, `neg`, `seqz`, `snez`, `j`, `jr`, `ret`, `call`, `beqz`, `bnez`. A pseudo `li` vira um único `addi` quando o valor cabe em 12 bits (-2048 a 2047). Caso contrário, vira `lui` + `addi`, com a correção de sinal descrita na spec. Com um rótulo (`li x29, rotulo`), carrega o endereço absoluto desse rótulo.

## Como usar com o processador

1. Carregue o `.hex` na memória a partir do endereço 0.
2. Faça o reset (PC = 0) e simule até o PC parar no laço final. O maior programa (10) executa cerca de 730 instruções, então 2000 ciclos bastam para um processador de ciclo único.
3. Confira `x31 == 1`. Se valer `0xBAD`, leia `x30` e procure o subteste correspondente no `README.md` da pasta.
4. Para os programas com memória, compare também os valores finais listados no README de cada pasta.
