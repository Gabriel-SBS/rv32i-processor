# RV32I Single-Cycle — Processador RISC-V em Verilog

Processador RISC-V de 32 bits e ciclo único, implementado em Verilog no **Programa CI Digital – CEPEDI**

> **Status:** processador completo, com as 40 instruções do RV32I base.
> Passa nos 12 programas de teste no Cadence Xcelium e sintetiza no Cadence Genus sem latches.

## Instruções suportadas

As 40 instruções do RV32I base (riscv-spec, capítulo 2):

| Classe | Instruções |
|---|---|
| Tipo R | `add` `sub` `sll` `slt` `sltu` `xor` `srl` `sra` `or` `and` |
| Tipo I (ULA) | `addi` `slti` `sltiu` `xori` `ori` `andi` `slli` `srli` `srai` |
| Loads | `lb` `lh` `lw` `lbu` `lhu` |
| Stores | `sb` `sh` `sw` |
| Desvios | `beq` `bne` `blt` `bge` `bltu` `bgeu` |
| Saltos | `jal` `jalr` |
| Tipo U | `lui` `auipc` |
| Sistema | `fence` `ecall` `ebreak` |

Por ser de ciclo único, sem cache e sem modo privilegiado:

- **`fence`** não tem efeito além de avançar o PC: os acessos à memória já acontecem na ordem do programa.
- **`ecall` e `ebreak`** param o processador: o PC fica parado na própria instrução (`PC_sel = 3`), nada mais é escrito e a saída `halt` do `processor` vai a 1. Só o reset tira o processador desse estado. Instruções de CSR (`csrrw`...) usam o mesmo opcode e também param, já que não fazem parte do RV32I base.
- Opcodes inválidos viram NOP (não escrevem, não desviam e não param).

```verilog
module processor #(parameter IMEM_FILE = "instructions/programs/10_algoritmo_final.hex")
                  (input clk, input rst_n, output [31:0] result, output halt);
```

`IMEM_FILE` escolhe o programa carregado na memória de instruções.

# Convenções

- **Reset `rst` ativo em nível baixo e assíncrono.** Com `rst = 0`, todos os registradores vão a zero na hora, sem esperar o clock.
- **Escrita síncrona** na borda de subida de `clk`.
- **`x0` é sempre zero.** Escritas em `x0` são ignoradas e a leitura de `x0` retorna 0.

## Módulos

### `reg_bank` — Banco de registradores

### `ALU` — Unidade Lógica e Aritmética

```verilog
module ALU (a, b, ALUControl, result, branch_taken);
```

Puramente combinacional. Os deslocamentos usam apenas `b[4:0]`. As comparações retornam `1` para verdadeiro e `0` para falso; nas de desvio, `branch_taken` repete esse bit. Nas operações do tipo R, o código é `{funct7[5], funct3}`.

| `ALUControl` | Operação | Resultado | Usada por |
|---|---|---|---|
| `0000` | ADD  | `a + b` | ADD, ADDI, loads, stores, AUIPC, JALR |
| `0001` | SLL  | `a << b[4:0]` | SLL, SLLI |
| `0010` | SLT  | `a < b` com sinal | SLT, SLTI |
| `0011` | SLTU | `a < b` sem sinal | SLTU, SLTIU |
| `0100` | XOR  | `a ^ b` | XOR, XORI |
| `0101` | SRL  | `a >> b[4:0]` | SRL, SRLI |
| `0110` | OR   | `a \| b` | OR, ORI |
| `0111` | AND  | `a & b` | AND, ANDI |
| `1000` | SUB  | `a - b` | SUB |
| `1001` | BEQ  | `a == b` | BEQ |
| `1010` | BNE  | `a != b` | BNE |
| `1011` | BGE  | `a >= b` com sinal | BGE |
| `1100` | BLT  | `a < b` com sinal | BLT |
| `1101` | SRA  | `a >>> b[4:0]` (mantém o sinal) | SRA, SRAI |
| `1110` | BLTU | `a < b` sem sinal | BLTU |
| `1111` | BGEU | `a >= b` sem sinal | BGEU |

### `regfile_alu` — Integração banco + ULA

### `pc` — Contador de programa

```verilog
module pc (clk, rst, a, o);
```

Registrador de 32 bits. Na borda de subida de `clk`, carrega o próximo endereço (`a`). Com `rst = 0`, vai para `0` na hora, então o programa sempre começa no endereço 0.

### `adder`, `mux2` e `mux4` — Blocos auxiliares

```verilog
module adder (a, b, o);                  // o = a + b
module mux2  (s, a, b, o);               // s = 1 -> a;  s = 0 -> b
module mux4  (s, a, b, c, d, o);         // s = 00 -> a, 01 -> b, 10 -> c, 11 -> d
```

## `pc_logic` — Cálculo do próximo PC

Junta o `pc`, dois `adder` e um `mux4`. Um somador calcula `PC + 4`; o outro, `PC + imm`. O `mux4` escolhe o próximo endereço pelo sinal `PCSel`:

| `PCSel` | Próximo PC | Usado em |
|---|---|---|
| `00` | `PC + 4` | execução sequencial e desvio não tomado |
| `01` | `alu_result` com o bit 0 zerado | JALR: `(rs1 + imm) & ~1` |
| `10` | `PC + imm` | desvio tomado (BEQ, BNE, ...) e JAL |
| `11` | `PC` (parado) | ECALL e EBREAK: o processador para |

A saída `pc_plus4` também é o endereço de retorno que o JAL e o JALR gravam em `rd` (`RegSel = 3`).

## Testes

Os testbenches comparam cada resultado com o valor esperado e terminam com `PASSOU` ou `FALHOU`.

| Testbench | Verificações | O que é testado |
|---|---|---|
| `tb_alu` | 30 | as 14 operações, com casos de borda: estouro com e sem sinal, deslocamento por 31, `shamt` usando só `b[4:0]`, comparações com e sem sinal, código não usado |
| `tb_pc` | 11 | PC fica em 0 durante o reset; carrega o novo valor só na borda de subida; não muda entre bordas; reset assíncrono |
| `tb_adder` | 8 | `PC + 4`, imediato positivo e negativo (desvio para frente e para trás), estouro de 32 bits |
| `tb_mux4` | 7 | as 4 seleções; mudar uma entrada não selecionada não altera a saída |
| `tb_pc_logic` | 19 | sequência de PCs com execução sequencial, desvio para frente e para trás, JAL, JALR (com bit 0 zerado), PC parado (`PC_sel = 3`), desvio não tomado e reset assíncrono |
| `tb_mux2` | 207 | as 2 seleções; mudar a entrada não selecionada não altera a saída; 200 casos aleatórios |
| `tb_alu_ref` | 23400 | todos os códigos × pares de valores-limite, deslocamentos de 0 a 31 e 20 mil casos aleatórios contra um modelo de referência |
| `tb_register_file` | 1214 | reset, escrita e leitura nas duas portas, `x0` fixo em zero, `we = 0`, escrita só na borda, valores-limite e 500 casos aleatórios contra um modelo |
| `tb_regfile_alu` | 5168 | banco + ULA executando instruções em sequência, com dependências, `x0`, `we = 0`, reset no meio e 5000 instruções aleatórias |
| `tb_data_memory` | 3559 | reset síncrono zera as 512 palavras; `sw`/`lw` em todas; `sb`/`sh` só mudam os bytes do acesso; `lb`/`lh` com sinal e `lbu`/`lhu` com zeros; `0x400` e `0x500` sem aliasing; escrita só na borda; `we = 0`; reset tem prioridade; 2000 acessos aleatórios contra um modelo byte a byte |
| `tb_instruction_memory` | 46 | leitura de todas as palavras do HEX, bits 1:0 ignorados, posições não carregadas e endereço acima da memória |
| `tb_imm_gen` | 4526 | formatos I, S, B, U e J com instruções reais (imediatos positivos, negativos e bits 11/12 de B e J) e 500 instruções aleatórias por opcode |
| `tb_alu_controller` | 329 | todas as combinações de `ALU_Op` × `funct3`; `funct7[5]` escolhe SUB/SRA só onde deve (ADDI negativo não vira SUB) |
| `tb_controller` | 278 | sinais de controle (inclusive `halt`) das 11 classes de instrução com desvio tomado e não tomado; os 128 opcodes (inválidos não escrevem, não desviam e não param) |
| `tb_processor` | 35 por programa | roda os 12 programas de `instructions/programs/` até o laço final ou até `ecall`/`ebreak`, espera 5 ciclos (o PC não pode sair do lugar) e confere `x31 = 1`, o PC final e os 32 registradores contra o simulador de referência |

O `tb_processor` escolhe o programa com `+TEST=<nome>`. Os arquivos `.regs` têm os 32 registradores e o PC finais calculados pelo `rv32i_sim.py` (do `arquivos_assembly.zip`). Os programas 11 (`fence` e `ebreak`) e 12 (`ecall`) têm o fonte `.s` na mesma pasta; para eles, o montador e o simulador de referência foram estendidos com essas três instruções (`fence` = NOP; `ecall`/`ebreak` = parada).

### Como rodar (Cadence Xcelium)

```bash
sim/run_xrun.sh                         # todos os testbenches e os 12 programas
sim/run_xrun.sh tb_alu tb_processor     # só os indicados
WAVES=1 sim/run_xrun.sh tb_processor    # grava as formas de onda em sim/build/*.shm
```

Para ver as formas de onda do processador no SimVision, já com os sinais agrupados (busca, decodificação, controle, ULA, memória e status do teste):

```bash
SHM=sim/build/tb_processor_05_lui_auipc.shm CURSOR=364 simvision -input sim/simvision_processor.tcl
```

### Situação atual do processador

Os 12 programas passam, com o mesmo número de ciclos que o simulador de referência (de 5 ciclos no 12 a 723 no 10). Três bugs foram encontrados pelos programas 01 a 10 e corrigidos:

| Programa | Bug | Correção |
|---|---|---|
| 05 `lui_auipc` | AUIPC dava PC + 2·imm: o `mux` de `src_a` usava `pc_target` (PC + imm) em vez de `pc` | `src_a` recebe `pc` quando `rs1_sel = 1` |
| 07 `load_store_byte_half` | LB, LH, LBU, LHU, SB e SH não existiam: a memória só lia e escrevia palavras inteiras | a `data_memory` recebe `funct3` e o endereço em bytes; escreve só os bytes do acesso e estende o sinal na leitura |
| 10 `algoritmo_final` | a `data_memory` tinha 64 palavras (`result[7:2]`): `0x400` e `0x500` caíam na mesma posição | memória de 512 palavras (2 KiB), parâmetro `DM_ADDR_W = 9` |

## Síntese (Cadence Genus)

```bash
cd syn && genus -files genus.tcl -log build/genus     # relatórios em syn/build/
```

O script usa a biblioteca de exemplo que vem com o Genus (`tutorial.lib`, 12 células e sem tecnologia real). Para usar a biblioteca do PDK, defina `LIB_PATH` e `LIB_NAME`; `PERIODO` muda o período do clock (padrão 20 ns). As memórias de instruções e de dados ficam como caixas-pretas, porque num chip seriam macros de SRAM/ROM e a de instruções depende de `$readmemh`, que a síntese ignora.

Resultado com a `tutorial.lib`:

| Item | Valor |
|---|---|
| Latches | 0 |
| Flip-flops | 1024 (31 registradores × 32 bits, já que `x0` nunca é escrito, mais os 32 bits do PC) |
| Células | 11768 (35,8% da área em flip-flops) |
| Maior caminho do núcleo | 10,4 ns: leitura do banco → ULA → write-back no banco (sem o tempo das memórias) |

Os números de área e de tempo só valem para essa biblioteca.


## Próximas etapas

- [x] Banco de registradores
- [x] ULA
- [x] Integração banco de registradores + ULA
- [x] PC (`pc`) e somadores (`adder`): PC + 4 e destino de desvio e salto
- [x] Memória de instruções (`imem`) carregada de `imem.hex`
- [x] Memória de dados (`dmem`)
- [x] Gerador de imediatos (`imm_gen`)
- [x] Unidade de controle (`controller`, `alu_controller`) e `mux4`
- [x] Integração do processador completo
- [x] Programas de teste em assembly e em hexadecimal
- [x] Testbench do processador
- [x] RV32I base completo: `fence`, `ecall` e `ebreak`
- [x] Síntese no Genus (biblioteca de exemplo)
- [ ] Síntese com a biblioteca do PDK e as memórias como macros
- [ ] Relatório com formas de onda comentadas
