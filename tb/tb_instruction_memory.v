`timescale 1ns/1ps

// Execute a partir da pasta que contem rtl/, tb/ e instructions/:
// iverilog -s tb_instruction_memory -o /tmp/tb_instruction_memory.vvp \
//   rtl/instruction_memory.v tb/tb_instruction_memory.v
// vvp /tmp/tb_instruction_memory.vvp
module tb_instruction_memory;

  localparam MEM_SIZE = 256;
  // palavras no .hex atual (mudar se o programa crescer)
  localparam PROGRAM_WORDS = 37;

  reg  [31:0] addr;
  wire [31:0] data;
  reg  [31:0] expected [0:PROGRAM_WORDS-1];
  integer i;
  integer hex_file;
  integer errors = 0;
  integer checks = 0;

  instruction_memory #(.MEM_SIZE(MEM_SIZE)) dut (
    .addr(addr),
    .data(data)
  );

  task check_read;
    input [31:0] address;
    input [31:0] expected_data;
    begin
      addr = address;
      #1; // leitura combinacional, sem clock
      checks = checks + 1;
      if (data !== expected_data) begin
        errors = errors + 1;
        $display("[ERRO] addr=%h -> data=%h, esperado=%h",
                 addr, data, expected_data);
      end
    end
  endtask

  initial begin
    addr = 0;
    hex_file = $fopen("instructions/imem.hex", "r");
    if (hex_file == 0)
      $fatal(1, "HEX nao encontrado: execute a partir da pasta que contem instructions/");
    $fclose(hex_file);
    $readmemh("instructions/imem.hex", expected);

    // se o .hex não carregou direito, para aqui em vez de comparar X com X
    for (i = 0; i < PROGRAM_WORDS; i = i + 1) begin
      if ((^expected[i]) === 1'bx)
        $fatal(1, "Palavra %0d ausente ou indefinida no HEX", i);
    end

    // endereço em bytes: 0, 4, 8, ... = palavras seguidas
    for (i = 0; i < PROGRAM_WORDS; i = i + 1)
      check_read(i * 4, expected[i]);

    // volta para o início e pula para o fim
    check_read(0, expected[0]);
    check_read((PROGRAM_WORDS - 1) * 4, expected[PROGRAM_WORDS - 1]);

    // bits 1:0 são ignorados (não tem exceção de desalinhamento)
    check_read(1, expected[0]);
    check_read(2, expected[0]);
    check_read(3, expected[0]);

    // posições que o .hex não preenche ficam em X
    check_read(PROGRAM_WORDS * 4, 32'hxxxx_xxxx);
    check_read((MEM_SIZE - 1) * 4, 32'hxxxx_xxxx);
    // só addr[9:2] conta, então endereço acima do fim dá a volta
    check_read(MEM_SIZE * 4, expected[0]);
    check_read(32'hffff_fffc, 32'hxxxx_xxxx);   // = palavra MEM_SIZE - 1

    if (errors != 0) begin
      $display("tb_instruction_memory: FALHOU (%0d erros em %0d verificacoes)",
               errors, checks);
      $fatal(1, "Falha na memoria de instrucoes");
    end
    $display("tb_instruction_memory: PASSOU (%0d verificacoes)", checks);
    $finish;
  end

endmodule
