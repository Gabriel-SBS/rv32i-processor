#!/usr/bin/env python3
"""Montador mínimo RV32I -> .hex (uma palavra de 32 bits por linha).

Codificações conforme o riscv-spec.pdf (Volume I, cap. 2 "RV32I Base Integer
Instruction Set" e cap. 24 "RV32/64G Instruction Set Listings").

Uso:
    python3 rv32i_asm.py programa.s [-o programa.hex] [--lst]
    python3 rv32i_asm.py --teste        # autoteste de codificação

Sintaxe aceita:
    - comentários com '#' ou '//'
    - rótulos 'nome:' (sozinhos ou antes de uma instrução)
    - registradores x0..x31 ou nomes ABI (zero, ra, sp, gp, tp, t0-t6, s0-s11, fp, a0-a7)
    - imediatos decimais, hexadecimais (0x..) ou binários (0b..), com sinal opcional
    - acesso à memória no formato  offset(reg)
    - pseudoinstruções: nop, li, la, mv, not, neg, seqz, snez, j, jr, ret,
      call, beqz, bnez
"""
import re
import sys

# ---------------------------------------------------------------------------
# Registradores
# ---------------------------------------------------------------------------
ABI = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15, "a6": 16, "a7": 17,
    "s2": 18, "s3": 19, "s4": 20, "s5": 21, "s6": 22, "s7": 23, "s8": 24, "s9": 25,
    "s10": 26, "s11": 27, "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}


def reg(nome):
    nome = nome.strip().lower()
    if nome in ABI:
        return ABI[nome]
    m = re.fullmatch(r"x(\d+)", nome)
    if m and int(m.group(1)) < 32:
        return int(m.group(1))
    raise ValueError(f"registrador inválido: '{nome}'")


# ---------------------------------------------------------------------------
# Tabelas de instruções (opcode, funct3, funct7)
# ---------------------------------------------------------------------------
OP_LUI, OP_AUIPC, OP_JAL, OP_JALR = 0x37, 0x17, 0x6F, 0x67
OP_BRANCH, OP_LOAD, OP_STORE = 0x63, 0x03, 0x23
OP_IMM, OP_REG = 0x13, 0x33

R_TYPE = {  # nome: (funct3, funct7)
    "add": (0, 0x00), "sub": (0, 0x20), "sll": (1, 0x00), "slt": (2, 0x00),
    "sltu": (3, 0x00), "xor": (4, 0x00), "srl": (5, 0x00), "sra": (5, 0x20),
    "or": (6, 0x00), "and": (7, 0x00),
}
I_ALU = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
I_SHIFT = {"slli": (1, 0x00), "srli": (5, 0x00), "srai": (5, 0x20)}
LOADS = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORES = {"sb": 0, "sh": 1, "sw": 2}
BRANCHES = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}


# ---------------------------------------------------------------------------
# Formatos de codificação (Figura 2.3 / 2.4 da spec)
# ---------------------------------------------------------------------------
def enc_r(op, rd, f3, rs1, rs2, f7):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(op, rd, f3, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(op, f3, rs1, rs2, imm):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op


def enc_b(op, f3, rs1, rs2, imm):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) \
        | (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | op


def enc_u(op, rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(op, rd, imm):
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) \
        | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | op


# ---------------------------------------------------------------------------
# Auxiliares
# ---------------------------------------------------------------------------
def numero(txt):
    txt = txt.strip().lower().replace("_", "")
    neg = txt.startswith("-")
    if neg or txt.startswith("+"):
        txt = txt[1:]
    if txt.startswith("0x"):
        v = int(txt, 16)
    elif txt.startswith("0b"):
        v = int(txt, 2)
    elif txt.isdigit():
        v = int(txt)
    else:
        raise ValueError(f"número inválido: '{txt}'")
    return -v if neg else v


def eh_numero(txt):
    try:
        numero(txt)
        return True
    except ValueError:
        return False


def checa_faixa(v, bits, nome):
    lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    if not lo <= v <= hi:
        raise ValueError(f"imediato {v} fora da faixa de {nome} ({lo}..{hi})")


def divide_hi_lo(valor):
    """Divide um valor de 32 bits em (hi20, lo12) para lui+addi, com correção de sinal."""
    valor &= 0xFFFFFFFF
    lo = valor & 0xFFF
    if lo & 0x800:
        lo -= 0x1000
    hi = ((valor - lo) >> 12) & 0xFFFFF
    return hi, lo


def mem_operando(txt):
    m = re.fullmatch(r"\s*([^()]*)\(\s*([^()]+)\s*\)\s*", txt)
    if not m:
        raise ValueError(f"operando de memória inválido: '{txt}' (use offset(reg))")
    off = m.group(1).strip() or "0"
    return numero(off), reg(m.group(2))


# ---------------------------------------------------------------------------
# Montador em duas passadas
# ---------------------------------------------------------------------------
class Montador:
    def __init__(self):
        self.rotulos = {}

    def valor(self, txt):
        txt = txt.strip()
        if eh_numero(txt):
            return numero(txt)
        if txt in self.rotulos:
            return self.rotulos[txt]
        raise ValueError(f"rótulo indefinido: '{txt}'")

    def alvo_relativo(self, txt, pc):
        txt = txt.strip()
        if eh_numero(txt):
            return numero(txt)          # deslocamento literal
        return self.valor(txt) - pc     # rótulo -> deslocamento relativo ao PC

    # Quantas instruções reais uma linha gera (necessário na 1ª passada).
    @staticmethod
    def tamanho(mn, ops):
        if mn == "li":
            if eh_numero(ops[1]):
                v = numero(ops[1])
                return 1 if -2048 <= v <= 2047 else 2
            return 2                     # li com rótulo: sempre lui+addi
        if mn == "la":
            return 2
        return 1

    def expande(self, mn, ops, pc):
        """Converte pseudoinstruções em instruções reais: lista de (mn, ops)."""
        if mn == "nop":
            return [("addi", ["x0", "x0", "0"])]
        if mn == "li":
            rd, imm = ops
            v = self.valor(imm)
            if eh_numero(imm) and -2048 <= v <= 2047:
                return [("addi", [rd, "x0", str(v)])]
            hi, lo = divide_hi_lo(v)
            return [("lui", [rd, str(hi)]), ("addi", [rd, rd, str(lo)])]
        if mn == "la":
            rd, rot = ops
            hi, lo = divide_hi_lo(self.valor(rot) - pc)
            return [("auipc", [rd, str(hi)]), ("addi", [rd, rd, str(lo)])]
        if mn == "mv":
            return [("addi", [ops[0], ops[1], "0"])]
        if mn == "not":
            return [("xori", [ops[0], ops[1], "-1"])]
        if mn == "neg":
            return [("sub", [ops[0], "x0", ops[1]])]
        if mn == "seqz":
            return [("sltiu", [ops[0], ops[1], "1"])]
        if mn == "snez":
            return [("sltu", [ops[0], "x0", ops[1]])]
        if mn == "j":
            return [("jal", ["x0", ops[0]])]
        if mn == "call":
            return [("jal", ["x1", ops[0]])]
        if mn == "jr":
            return [("jalr", ["x0", f"0({ops[0]})"])]
        if mn == "ret":
            return [("jalr", ["x0", "0(x1)"])]
        if mn == "beqz":
            return [("beq", [ops[0], "x0", ops[1]])]
        if mn == "bnez":
            return [("bne", [ops[0], "x0", ops[1]])]
        if mn == "jal" and len(ops) == 1:
            return [("jal", ["x1", ops[0]])]
        if mn == "jalr" and len(ops) == 1:
            return [("jalr", ["x1", f"0({ops[0]})"])]
        return [(mn, ops)]

    def codifica(self, mn, ops, pc):
        if mn in R_TYPE:
            f3, f7 = R_TYPE[mn]
            rd, rs1, rs2 = map(reg, ops)
            return enc_r(OP_REG, rd, f3, rs1, rs2, f7)
        if mn in I_ALU:
            rd, rs1 = reg(ops[0]), reg(ops[1])
            imm = self.valor(ops[2])
            if mn == "sltiu" and 0x800 <= imm <= 0xFFF:
                imm -= 0x1000            # aceita 0xFFF como -1 em sltiu
            checa_faixa(imm, 12, mn)
            return enc_i(OP_IMM, rd, I_ALU[mn], rs1, imm)
        if mn in I_SHIFT:
            f3, f7 = I_SHIFT[mn]
            rd, rs1 = reg(ops[0]), reg(ops[1])
            sh = self.valor(ops[2])
            if not 0 <= sh <= 31:
                raise ValueError(f"shamt {sh} fora de 0..31")
            return enc_i(OP_IMM, rd, f3, rs1, (f7 << 5) | sh)
        if mn in LOADS:
            rd = reg(ops[0])
            off, rs1 = mem_operando(ops[1])
            checa_faixa(off, 12, mn)
            return enc_i(OP_LOAD, rd, LOADS[mn], rs1, off)
        if mn in STORES:
            rs2 = reg(ops[0])
            off, rs1 = mem_operando(ops[1])
            checa_faixa(off, 12, mn)
            return enc_s(OP_STORE, STORES[mn], rs1, rs2, off)
        if mn in BRANCHES:
            rs1, rs2 = reg(ops[0]), reg(ops[1])
            off = self.alvo_relativo(ops[2], pc)
            checa_faixa(off, 13, mn)
            if off & 1:
                raise ValueError("deslocamento de desvio deve ser par")
            return enc_b(OP_BRANCH, BRANCHES[mn], rs1, rs2, off)
        if mn in ("lui", "auipc"):
            rd = reg(ops[0])
            imm = self.valor(ops[1])
            if not -(1 << 19) <= imm <= 0xFFFFF:
                raise ValueError(f"imediato de {mn} fora de 20 bits: {imm}")
            return enc_u(OP_LUI if mn == "lui" else OP_AUIPC, rd, imm)
        if mn == "jal":
            rd = reg(ops[0])
            off = self.alvo_relativo(ops[1], pc)
            checa_faixa(off, 21, mn)
            return enc_j(OP_JAL, rd, off)
        if mn == "jalr":
            rd = reg(ops[0])
            if len(ops) == 2:                    # jalr rd, off(rs1)
                off, rs1 = mem_operando(ops[1])
            else:                                # jalr rd, rs1, off
                rs1, off = reg(ops[1]), self.valor(ops[2])
            checa_faixa(off, 12, mn)
            return enc_i(OP_JALR, rd, 0, rs1, off)
        raise ValueError(f"instrução desconhecida: '{mn}'")

    @staticmethod
    def le_linhas(fonte):
        """Retorna lista de (nº linha, rótulos, mnemônico, operandos, texto original)."""
        itens = []
        for n, bruto in enumerate(fonte.splitlines(), 1):
            linha = re.split(r"#|//", bruto, maxsplit=1)[0].strip()
            rotulos = []
            while True:
                m = re.match(r"([A-Za-z_.][\w.]*)\s*:\s*(.*)", linha)
                if not m:
                    break
                rotulos.append(m.group(1))
                linha = m.group(2).strip()
            mn, ops = None, []
            if linha:
                partes = linha.split(None, 1)
                mn = partes[0].lower()
                if len(partes) > 1:
                    ops = [o.strip() for o in partes[1].split(",")]
            itens.append((n, rotulos, mn, ops, bruto.rstrip()))
        return itens

    def monta(self, fonte):
        itens = self.le_linhas(fonte)
        # 1ª passada: endereço de cada rótulo
        pc = 0
        for n, rotulos, mn, ops, _ in itens:
            for r in rotulos:
                if r in self.rotulos:
                    raise ValueError(f"linha {n}: rótulo duplicado '{r}'")
                self.rotulos[r] = pc
            if mn:
                pc += 4 * self.tamanho(mn, ops)
        # 2ª passada: codificação
        palavras, listagem, pc = [], [], 0
        for n, _, mn, ops, texto in itens:
            if not mn:
                continue
            try:
                for i, (m2, o2) in enumerate(self.expande(mn, ops, pc)):
                    w = self.codifica(m2, o2, pc)
                    palavras.append(w)
                    listagem.append(f"{pc:08X}  {w:08X}  {texto.strip() if i == 0 else '    (cont.)'}")
                    pc += 4
            except ValueError as e:
                raise ValueError(f"linha {n}: {e}\n    {texto.strip()}") from None
        return palavras, listagem


def para_hex(palavras):
    return "".join(f"{w:08X}\n" for w in palavras)


# ---------------------------------------------------------------------------
# Autoteste com codificações conhecidas
# ---------------------------------------------------------------------------
CASOS = [
    ("addi x1, x0, 5", 0x00500093),
    ("nop", 0x00000013),
    ("jal x0, 0", 0x0000006F),
    ("add x3, x1, x2", 0x002081B3),
    ("sub x3, x1, x2", 0x402081B3),
    ("lui x1, 0x12345", 0x123450B7),
    ("auipc x1, 0", 0x00000097),
    ("lw x2, 4(x10)", 0x00452103),
    ("sw x2, 8(x10)", 0x00252423),
    ("srai x1, x1, 31", 0x41F0D093),
    ("beq x1, x2, 8", 0x00208463),
    ("bne x1, x2, -4", 0xFE209EE3),
    ("jalr x0, 0(x1)", 0x00008067),
    ("addi x1, x0, -2048", 0x80000093),
]


def autoteste():
    erros = 0
    for src, esperado in CASOS:
        w, _ = Montador().monta(src)
        ok = w[0] == esperado
        erros += not ok
        print(f"{'OK  ' if ok else 'ERRO'} {src:24s} -> {w[0]:08X} (esperado {esperado:08X})")
    print("Autoteste:", "PASSOU" if not erros else f"{erros} FALHA(S)")
    return 0 if not erros else 1


def main(argv):
    if "--teste" in argv:
        return autoteste()
    args = [a for a in argv if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 1
    entrada = args[0]
    saida = args[args.index("-o") + 1] if "-o" in args else re.sub(r"\.s$", "", entrada) + ".hex"
    if "-o" in args:
        args.remove("-o")
    with open(entrada, encoding="utf-8") as f:
        fonte = f.read()
    try:
        palavras, listagem = Montador().monta(fonte)
    except ValueError as e:
        print(f"{entrada}: {e}", file=sys.stderr)
        return 1
    with open(saida, "w") as f:
        f.write(para_hex(palavras))
    if "--lst" in argv:
        print("\n".join(listagem))
    print(f"{entrada} -> {saida} ({len(palavras)} instruções, {4 * len(palavras)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
