# RV32I Single-Cycle — Processador RISC-V em Verilog

Processador RISC-V de 32 bits e ciclo único, implementado em Verilog no **Programa CI Digital – CEPEDI**

> **Status: processador completo (31/10/2026).**
> Todos os blocos do RV32I de ciclo único estão integrados. Os 14 testbenches unitários e os 10 programas de teste passam.

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

Puramente combinacional. Os deslocamentos usam apenas `b[4:0]`. As comparações retornam `1` para verdadeiro e `0` para falso.

A codificação segue o RISC-V: nas operações do tipo R, `ALUControl = {funct7[5], funct3}`. Os 16 códigos são usados.

| `ALUControl` | Operação | Resultado | Usada por |
|---|---|---|---|
| `0000` | ADD  | `a + b` | ADD, ADDI, loads, stores, LUI, AUIPC, JAL, JALR |
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

A saída `branch_taken` vale `1` só nos seis códigos de desvio (`BEQ` a `BGEU`) quando a condição é verdadeira. Em qualquer outra operação ela fica em `0`, mesmo que `result[0]` seja `1`. A unidade de controle usa esse sinal para decidir se o desvio é tomado.

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
| `10` | `PC + imm` | desvio tomado (`branch_taken = 1`) e JAL |
| `11` | `PC + 4` | não usado |

A saída `pc_plus4` também é o endereço de retorno que o JAL e o JALR gravam em `rd` (`RegSel = 3`).

## Testes

Os testbenches comparam cada resultado com o valor esperado e terminam com `PASSOU` ou `FALHOU`. A exceção é o `tb_alu`, que termina com `ALL TESTS PASSED` ou com o número de erros.

| Testbench | Verificações | O que é testado |
|---|---|---|
| `tb_alu` | 51 | as 16 operações com casos de borda (estouro, deslocamento por 0 e 31, `shamt` usando só `b[4:0]`, comparações com e sem sinal), os 6 desvios com condição verdadeira e falsa, e `branch_taken = 0` em todos os códigos que não são desvio |
| `tb_pc` | 11 | PC fica em 0 durante o reset; carrega o novo valor só na borda de subida; não muda entre bordas; reset assíncrono |
| `tb_adder` | 8 | `PC + 4`, imediato positivo e negativo (desvio para frente e para trás), estouro de 32 bits |
| `tb_mux4` | 7 | as 4 seleções; mudar uma entrada não selecionada não altera a saída |
| `tb_pc_logic` | 18 | sequência de PCs com execução sequencial, desvio para frente e para trás, JAL, JALR (com bit 0 zerado), desvio não tomado e reset assíncrono |
| `tb_mux2` | 207 | as 2 seleções; mudar a entrada não selecionada não altera a saída; 200 casos aleatórios |
| `tb_alu_ref` | 23400 | os 16 códigos × pares de valores-limite, deslocamentos de 0 a 31 e 20 mil casos aleatórios contra um modelo de referência, conferindo `result` e `branch_taken` |
| `tb_register_file` | 1214 | reset, escrita e leitura nas duas portas, `x0` fixo em zero, `we = 0`, escrita só na borda, valores-limite e 500 casos aleatórios contra um modelo |
| `tb_regfile_alu` | 5168 | banco + ULA executando instruções em sequência, com dependências, `x0`, `we = 0`, reset no meio e 5000 instruções aleatórias |
| `tb_data_memory` | 3559 | reset síncrono zera as 512 palavras; `sw`/`lw` em todas; `sb`/`sh` só mudam os bytes do acesso; `lb`/`lh` com sinal e `lbu`/`lhu` com zeros; `0x400` e `0x500` sem aliasing; escrita só na borda; `we = 0`; reset tem prioridade; 2000 acessos aleatórios contra um modelo byte a byte |
| `tb_instruction_memory` | 46 | leitura de todas as palavras do HEX, bits 1:0 ignorados, posições não carregadas e endereço acima da memória |
| `tb_imm_gen` | 4526 | formatos I, S, B, U e J com instruções reais (imediatos positivos, negativos e bits 11/12 de B e J) e 500 instruções aleatórias por opcode |
| `tb_alu_controller` | 329 | todas as combinações de `ALU_Op` × `funct3` com a codificação da `ALU`; `funct7[5]` escolhe SUB/SRA só onde deve (ADDI negativo não vira SUB) |
| `tb_controller` | 274 | sinais de controle das 9 classes de instrução com `branch_taken` = 0 e 1; os 128 opcodes (inválidos não escrevem nem desviam) |
| `tb_processor` | 34 por programa | roda os 10 programas de `instructions/programs/` até o laço final e confere `x31 = 1`, o PC final e os 32 registradores contra o simulador de referência |

O `tb_processor` escolhe o programa com `+TEST=<nome>`. Os arquivos `.regs` têm os 32 registradores e o PC finais calculados pelo `rv32i_sim.py`.

A pasta `instructions/arquivos_assembly/Treino_RISC_V/testes/` traz o código-fonte assembly (`.s`) de cada programa e, em `ferramentas/`, o que foi usado para gerar os testes: `rv32i_asm.py` (montador), `rv32i_sim.py` (simulador de referência) e `gerar_todos.sh`, que monta os 10 programas e gera os `.hex` e os `.regs`.

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

Os 10 programas passam, com o mesmo número de ciclos que o simulador de referência (de 51 ciclos no 04 a 723 no 10). Três bugs foram encontrados por eles e corrigidos:

| Programa | Bug | Correção |
|---|---|---|
| 05 `lui_auipc` | AUIPC dava PC + 2·imm: o `mux` de `src_a` usava `pc_target` (PC + imm) em vez de `pc` | `src_a` recebe `pc` quando `rs1_sel = 1` |
| 07 `load_store_byte_half` | LB, LH, LBU, LHU, SB e SH não existiam: a memória só lia e escrevia palavras inteiras | a `data_memory` recebe `funct3` e o endereço em bytes; escreve só os bytes do acesso e estende o sinal na leitura |
| 10 `algoritmo_final` | a `data_memory` tinha 64 palavras (`result[7:2]`): `0x400` e `0x500` caíam na mesma posição | memória de 512 palavras (2 KiB), parâmetro `DM_ADDR_W = 9` |


## Próximas etapas

- [x] Banco de registradores
- [x] ULA
- [x] Integração banco de registradores + ULA
- [x] PC (`pc`) e somadores (`adder`): PC + 4 e destino de desvio e salto
- [x] Memória de instruções (`instruction_memory`) carregada de `instructions/instruction_control.hex`
- [x] Memória de dados (`dmem`)
- [x] Gerador de imediatos (`imm_gen`)
- [x] Unidade de controle (`controller`, `alu_controller`) e `mux4`
- [x] Integração do processador completo
- [x] Programas de teste em assembly e em hexadecimal
- [x] Testbench do processador
- [x] Relatório com formas de onda comentadas (ver [relatorio/relatorio_final.tex](relatorio/relatorio_final.tex))
