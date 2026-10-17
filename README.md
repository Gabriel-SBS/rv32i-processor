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

### `regfile` — Banco de registradores

### `ALU` — Unidade Lógica e Aritmética

```verilog
module ALU (a, b, ALUControl, result);
```

Puramente combinacional. Os deslocamentos usam apenas `b[4:0]`. As comparações retornam `1` para verdadeiro e `0` para falso.

| `ALUControl` | Operação | Resultado | Usada por |
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


## Próximas etapas

- [x] Banco de registradores
- [x] ULA
- [x] Integração banco de registradores + ULA
- [x] PC (`pc`) e somadores (`adder`): PC + 4 e destino de desvio e salto
- [ ] Memória de instruções (`imem`) carregada de `imem.hex`
- [ ] Memória de dados (`dmem`)
- [ ] Gerador de imediatos (`extendImm`)
- [ ] Unidade de controle (`control`) e `mux4`
- [ ] Integração do processador completo
- [ ] Programas de teste em assembly e em hexadecimal
- [ ] Testbench do processador e relatório com formas de onda comentadas
