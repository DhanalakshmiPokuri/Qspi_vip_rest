class qspi_cfg extends uvm_object;

  typedef enum {MODE00, MODE03} spi_mode_e;
  typedef enum {STD_READ_03, FAST_READ_0B, QUAD_READ_EB} cmd_type_e;

  spi_mode_e  mode          = MODE00;        // our DUT uses mode 00
  cmd_type_e  cmd_type      = QUAD_READ_EB;  // default to Quad Read 0xEB for XiP
  int         dummy_cycles  = 4;             // expected dummy for 0xEB
  bit         quad_enable   = 1;             // flash QE status bit
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit         inject_error  = 0;             // future: corrupt data to test DUT
  int         data_bytes    = 16;            // default response length (16 bytes = 1 cache line)

  virtual qspi_if vif;

  `uvm_object_utils(qspi_cfg)

  function new(string name = "qspi_cfg");
    super.new(name);
  endfunction

  function bit [7:0] get_cmd_byte();
    case (cmd_type)
      STD_READ_03 : return 8'h03;
      FAST_READ_0B: return 8'h0B;
      QUAD_READ_EB: return 8'hEB;
    endcase
  endfunction

endclass


