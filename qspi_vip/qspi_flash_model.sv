class qspi_flash_model extends uvm_object;

  bit [7:0] mem [bit [23:0]];   // sparse flash memory
  int       size_bytes = 1 << 20;  // 1MB model

  `uvm_object_utils(qspi_flash_model)

  function new(string name = "qspi_flash_model");
    super.new(name);
  endfunction

  // Preload with deterministic pattern: mem[A] = f(A)
  // Scoreboard uses the SAME function to compute expected AHB data
    function void preload_pattern();
    for (int a = 0; a < size_bytes; a += 4) begin
      mem[a]   = ((a)     & 8'hFF) ^ ((a >> 8)  & 8'hFF) ^ 8'hA5;
      mem[a+1] = ((a + 1) & 8'hFF) ^ ((a >> 8)  & 8'hFF) ^ 8'h5A;
      mem[a+2] = ((a + 2) & 8'hFF) ^ ((a >> 16) & 8'hFF) ^ 8'h33;
      mem[a+3] = ((a + 3) & 8'hFF) ^ ((a >> 16) & 8'hFF) ^ 8'hCC;
    end
  endfunction
  function bit [7:0] read_byte(bit [23:0] addr);
    if (mem.exists(addr))
    return mem[addr];
    else           
  return 8'hFF;  // erased flash reads FF
  endfunction

endclass

