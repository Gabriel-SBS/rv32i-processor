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

### `regfile_alu` — Integração banco + ULA

## Testes

## Próximas etapas

- [x] Banco de registradores
- [x] ULA
- [x] Integração banco de registradores + ULA
- [ ] PC (`pc`) e somadores (`adder`): PC + 4 e destino de desvio e salto
- [ ] Memória de instruções (`imem`) carregada de `imem.hex`
- [ ] Memória de dados (`dmem`)
- [ ] Gerador de imediatos (`extendImm`)
- [ ] Unidade de controle (`control`) e `mux4`
- [ ] Integração do processador completo
- [ ] Programas de teste em assembly e em hexadecimal
- [ ] Testbench do processador e relatório com formas de onda comentadas
