class qspi_txn extends uvm_sequence_item;

  // Captured command info (what the DUT sent)
  rand bit [7:0]   cmd;          // 0x03 / 0x0B / 0xEB
  rand bit [23:0]  addr ;         // 24-bit flash address
  rand bit [7:0]   mode_bits;    // M7..M0 for 0xEB (XIP continuous)
  rand int         dummy_cycles; // clocks between addr/mode and data

  // Data (what flash returned)
  rand bit [7:0]   data[];       // bytes returned by flash
  bit              continuous_read; 

  `uvm_object_utils(qspi_txn)

  constraint c_cmd   { cmd inside {8'h03, 8'h0B, 8'hEB}; }
  constraint c_dummy {
    (cmd == 8'h03) -> dummy_cycles == 0;
    (cmd == 8'h0B) -> dummy_cycles inside {[2:16]};
    (cmd == 8'hEB) -> dummy_cycles inside {[2:8]};
  }

  function new(string name = "qspi_txn");
    super.new(name);
  endfunction

  // manual methods
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("cmd",cmd,8, UVM_HEX);
    printer.print_field("addr",addr,24, UVM_HEX);
    printer.print_field("mode_bits",mode_bits, 8, UVM_HEX);
    printer.print_field("dummy",dummy_cycles, 32, UVM_DEC);
    printer.print_field("cont_read",continuous_read, 1, UVM_BIN);
    foreach (data[i])
      printer.print_field($sformatf("data[%0d]", i), data[i], 8, UVM_HEX);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    qspi_txn that;
    super.do_copy(rhs);
    assert($cast(that, rhs));
    cmd             = that.cmd;
    addr            = that.addr;
    mode_bits       = that.mode_bits;
    dummy_cycles    = that.dummy_cycles;
    data            = new[that.data.size()](that.data);
    continuous_read = that.continuous_read;
  endfunction

endclass

