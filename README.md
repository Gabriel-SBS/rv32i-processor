# RV32I Single-Cycle — Processador RISC-V em Verilog

Processador RISC-V de 32 bits e ciclo único, implementado em Verilog no **Programa CI Digital – CEPEDI**

> **Status: entrega parcial (17/10/2026).**
> Prontos: banco de registradores, ULA e a integração dos dois, cada um com seu testbench.
> O processador completo (PC, memórias, gerador de imediatos e unidade de controle) ainda está em desenvolvimento.

# Convenções

- **Reset `rst` ativo em nível baixo e assíncrono.** Com `rst = 0`, todos os registradores vão a zero na hora, sem esperar o clock.
- **Escrita síncrona** na borda de subida de `clk`.
- **`x0` é sempre zero.** Escritas em `x0` são ignoradas e a leitura de `x0` retorna 0.

## Módulos

### `reg_bank` — Banco de registradores

### `alu` — Unidade Lógica e Aritmética

```verilog
module alu (a, b, ALU_Control, result);
```

Puramente combinacional. Os deslocamentos usam apenas `b[4:0]`. As comparações retornam `1` para verdadeiro e `0` para falso.

| `ALU_Control` | Operação | Resultado | Usada por |
|---|---|---|---|
| `0000` | ADD  | `a + b` | ADD, ADDI, LW, SW, AUIPC, JALR |
| `0001` | SUB  | `a - b` | SUB |
| `0010` | AND  | `a & b` | AND, ANDI |
| `0011` | OR   | `a \| b` | OR, ORI |
| `0100` | XOR  | `a ^ b` | XOR, XORI |
| `0101` | SLL  | `a << b[4:0]` | SLL, SLLI |
| `0110` | SRL  | `a >> b[4:0]` | SRL, SRLI |
| `0111` | SRA  | `a >>> b[4:0]` (mantém o sinal) | SRA, SRAI |
| `1000` | EQ   | `a == b` | BEQ |
| `1001` | ULT  | `a < b` sem sinal | SLTU, SLTIU, BLTU |
| `1010` | UGTE | `a >= b` sem sinal | BGEU |
| `1011` | SLT  | `a < b` com sinal | SLT, SLTI, BLT |
| `1100` | SGTE | `a >= b` com sinal | BGE |
| `1101` | NE   | `a != b` | BNE |

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
| `11` | `PC + 4` | não usado |

A saída `pc_plus4` também é o endereço de retorno que o JAL e o JALR gravam em `rd` (`RegSel = 3`).

## Testes

Os testbenches comparam cada resultado com o valor esperado e terminam com `PASSOU` ou `FALHOU`.

| Testbench | Verificações | O que é testado |
|---|---|---|
| `tb_alu` | 30 | as 14 operações, com casos de borda: estouro com e sem sinal, deslocamento por 31, `shamt` usando só `b[4:0]`, comparações com e sem sinal, código não usado |
| `tb_pc` | 11 | PC fica em 0 durante o reset; carrega o novo valor só na borda de subida; não muda entre bordas; reset assíncrono |
| `tb_adder` | 8 | `PC + 4`, imediato positivo e negativo (desvio para frente e para trás), estouro de 32 bits |
| `tb_mux4` | 7 | as 4 seleções; mudar uma entrada não selecionada não altera a saída |
| `tb_pc_logic` | 18 | sequência de PCs com execução sequencial, desvio para frente e para trás, JAL, JALR (com bit 0 zerado), desvio não tomado e reset assíncrono |
| `tb_mux2` | 207 | as 2 seleções; mudar a entrada não selecionada não altera a saída; 200 casos aleatórios |
| `tb_alu_ref` | 23400 | todos os códigos × pares de valores-limite, deslocamentos de 0 a 31 e 20 mil casos aleatórios contra um modelo de referência |
| `tb_register_file` | 1214 | reset, escrita e leitura nas duas portas, `x0` fixo em zero, `we = 0`, escrita só na borda, valores-limite e 500 casos aleatórios contra um modelo |
| `tb_regfile_alu` | 5168 | banco + ULA executando instruções em sequência, com dependências, `x0`, `we = 0`, reset no meio e 5000 instruções aleatórias |
| `tb_data_memory` | 1204 | reset síncrono zera as 64 palavras; escrita só na borda de subida; leitura combinacional; `we = 0`; reset tem prioridade; 1000 casos aleatórios |
| `tb_instruction_memory` | 46 | leitura de todas as palavras do HEX, bits 1:0 ignorados, posições não carregadas e endereço acima da memória |
| `tb_imm_gen` | 4526 | formatos I, S, B, U e J com instruções reais (imediatos positivos, negativos e bits 11/12 de B e J) e 500 instruções aleatórias por opcode |
| `tb_alu_controller` | 329 | todas as combinações de `ALU_Op` × `funct3`; `funct7[5]` escolhe SUB/SRA só onde deve (ADDI negativo não vira SUB) |
| `tb_controller` | 274 | sinais de controle das 9 classes de instrução com desvio tomado e não tomado; os 128 opcodes (inválidos não escrevem nem desviam) |
| `tb_processor` | 34 por programa | roda os 10 programas de `instructions/programs/` até o laço final e confere `x31 = 1`, o PC final e os 32 registradores contra o simulador de referência |

O `tb_processor` escolhe o programa com `+TEST=<nome>`. Os arquivos `.regs` têm os 32 registradores e o PC finais calculados pelo `rv32i_sim.py` (do `arquivos_assembly.zip`).

### Como rodar (Cadence Xcelium)

```bash
sim/run_xrun.sh                         # todos os testbenches e os 10 programas
sim/run_xrun.sh tb_alu tb_processor     # só os indicados
WAVES=1 sim/run_xrun.sh tb_processor    # grava as formas de onda em sim/build/*.shm
```

Para ver as formas de onda do processador no SimVision, já com os sinais agrupados (busca, decodificação, controle, ULA, memória e status do teste):

```bash
SHM=sim/build/tb_processor_05_lui_auipc.shm CURSOR=364 simvision -input sim/simvision_processor.tcl
```

### Situação atual do processador

| Programa | Resultado | Causa |
|---|---|---|
| 01, 02, 03, 04, 06, 08, 09 | PASSOU | número de ciclos igual ao da referência |
| 05 `lui_auipc` | FALHOU no subteste 7 | AUIPC: o `mux` de `src_a` no `datapath` usa `pc_target` (PC + imm) em vez de `pc`, então o resultado é PC + 2·imm |
| 07 `load_store_byte_half` | FALHOU no subteste 1 | LB, LH, LBU, LHU, SB e SH não estão implementados: a memória só lê e escreve palavras inteiras |
| 10 `algoritmo_final` | FALHOU no subteste 3 | a `data_memory` tem 64 palavras endereçadas por `result[7:2]`: `0x400` e `0x500` caem na mesma posição e o Fibonacci sobrescreve o vetor. Os programas precisam de pelo menos 2 KiB |


## Próximas etapas

- [x] Banco de registradores
- [x] ULA
- [x] Integração banco de registradores + ULA
- [x] PC (`pc`) e somadores (`adder`): PC + 4 e destino de desvio e salto
- [x] Memória de instruções (`imem`) carregada de `imem.hex`
- [x] Memória de dados (`dmem`)
- [ ] Gerador de imediatos (`extendImm`)
- [ ] Unidade de controle (`control`) e `mux4`
- [ ] Integração do processador completo
- [ ] Programas de teste em assembly e em hexadecimal
- [ ] Testbench do processador e relatório com formas de onda comentadas
