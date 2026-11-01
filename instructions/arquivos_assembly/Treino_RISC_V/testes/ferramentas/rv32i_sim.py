#!/usr/bin/env python3
"""Simulador de referência RV32I para conferir os programas de teste.

Carrega um .hex (uma palavra de 32 bits por linha, endereço 0) numa memória
unificada de 4 KiB, executa até encontrar a instrução de parada 'jal x0, 0'
(0000006F, o laço 'fim: j fim') e verifica a convenção:
    x31 = 1      -> sucesso
    x31 = 0xBAD  -> falha (x30 indica o subteste que falhou)

Uso:
    python3 rv32i_sim.py programa.hex [--regs] [--mem ENDERECO QTD]
"""
import sys

TAM_MEM = 4096
MAX_PASSOS = 200_000
PARADA = 0x0000006F


def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


class CPU:
    def __init__(self, palavras):
        self.x = [0] * 32
        self.pc = 0
        self.mem = bytearray(TAM_MEM)
        for i, w in enumerate(palavras):
            self.mem[4 * i:4 * i + 4] = w.to_bytes(4, "little")

    def le(self, end, n):
        if end + n > TAM_MEM:
            raise RuntimeError(f"leitura fora da memória: 0x{end:08X}")
        return int.from_bytes(self.mem[end:end + n], "little")

    def escreve(self, end, n, v):
        if end + n > TAM_MEM:
            raise RuntimeError(f"escrita fora da memória: 0x{end:08X}")
        self.mem[end:end + n] = (v & ((1 << (8 * n)) - 1)).to_bytes(n, "little")

    def passo(self):
        ins = self.le(self.pc, 4)
        op = ins & 0x7F
        rd = (ins >> 7) & 0x1F
        f3 = (ins >> 12) & 7
        rs1 = (ins >> 15) & 0x1F
        rs2 = (ins >> 20) & 0x1F
        f7 = ins >> 25
        a, b = self.x[rs1], self.x[rs2]
        imm_i = sx(ins >> 20, 12)
        imm_s = sx(((ins >> 25) << 5) | ((ins >> 7) & 0x1F), 12)
        imm_b = sx((((ins >> 31) & 1) << 12) | (((ins >> 7) & 1) << 11)
                   | (((ins >> 25) & 0x3F) << 5) | (((ins >> 8) & 0xF) << 1), 13)
        imm_u = ins & 0xFFFFF000
        imm_j = sx((((ins >> 31) & 1) << 20) | (((ins >> 12) & 0xFF) << 12)
                   | (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3FF) << 1), 21)
        prox = self.pc + 4
        res = None

        if op == 0x37:                                  # LUI
            res = imm_u
        elif op == 0x17:                                # AUIPC
            res = self.pc + imm_u
        elif op == 0x6F:                                # JAL
            res, prox = self.pc + 4, self.pc + imm_j
        elif op == 0x67:                                # JALR
            res, prox = self.pc + 4, (a + imm_i) & ~1
        elif op == 0x63:                                # BRANCH
            sa, sb = sx(a, 32), sx(b, 32)
            cond = {0: a == b, 1: a != b, 4: sa < sb, 5: sa >= sb, 6: a < b, 7: a >= b}[f3]
            if cond:
                prox = self.pc + imm_b
        elif op == 0x03:                                # LOAD
            end = (a + imm_i) & 0xFFFFFFFF
            n = {0: 1, 1: 2, 2: 4, 4: 1, 5: 2}[f3]
            v = self.le(end, n)
            res = sx(v, 8 * n) if f3 in (0, 1) else v
        elif op == 0x23:                                # STORE
            end = (a + imm_s) & 0xFFFFFFFF
            self.escreve(end, {0: 1, 1: 2, 2: 4}[f3], b)
        elif op in (0x13, 0x33):                        # OP-IMM / OP
            if op == 0x13:
                b = imm_i & 0xFFFFFFFF
                sub = False
                sra = f3 == 5 and (ins >> 30) & 1
            else:
                sub = f3 == 0 and f7 == 0x20
                sra = f3 == 5 and f7 == 0x20
            sh = b & 0x1F
            res = {
                0: a - b if sub else a + b,
                1: a << sh,
                2: int(sx(a, 32) < sx(b, 32)),
                3: int(a < b),
                4: a ^ b,
                5: (sx(a, 32) >> sh) if sra else (a >> sh),
                6: a | b,
                7: a & b,
            }[f3]
        else:
            raise RuntimeError(f"instrução inválida 0x{ins:08X} em pc=0x{self.pc:08X}")

        if res is not None and rd != 0:
            self.x[rd] = res & 0xFFFFFFFF
        self.pc = prox & 0xFFFFFFFF

    def executa(self):
        for passos in range(MAX_PASSOS):
            if self.le(self.pc, 4) == PARADA:
                return passos
            self.passo()
        raise RuntimeError("limite de passos atingido (laço infinito inesperado?)")


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    with open(argv[0]) as f:
        palavras = [int(l.strip(), 16) for l in f if l.strip()]
    cpu = CPU(palavras)
    try:
        passos = cpu.executa()
    except RuntimeError as e:
        print(f"{argv[0]}: ERRO: {e}")
        return 1
    if "--regs" in argv:
        for i in range(0, 32, 4):
            print("  ".join(f"x{j:<2}={cpu.x[j]:08X}" for j in range(i, i + 4)))
    if "--mem" in argv:
        k = argv.index("--mem")
        base, qtd = int(argv[k + 1], 0), int(argv[k + 2], 0)
        for e in range(base, base + 4 * qtd, 4):
            print(f"  [{e:08X}] = {cpu.le(e, 4):08X}")
    ok = cpu.x[31] == 1
    estado = "PASSOU" if ok else f"FALHOU no subteste {cpu.x[30]} (x31=0x{cpu.x[31]:X})"
    print(f"{argv[0]}: {estado}  [{passos} instruções executadas, parada em pc=0x{cpu.pc:08X}]")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
