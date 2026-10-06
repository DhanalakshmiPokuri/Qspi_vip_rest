class ahb_base_seq extends uvm_sequence #(ahb_txn);
  `uvm_object_utils(ahb_base_seq)

  // Knobs that tests can set:
  rand bit [31:0] start_addr = 32'h0;
  rand bit do_write   = 0;           // default: read
  rand ahb_burst_e  burst_type = AHB_SINGLE;   // default: SINGLE
  rand bit [2:0] size       = 3'b010;       // default: word (32-bit)
  rand bit [31:0] wdata      = 32'h0;

  function new(string name = "ahb_base_seq");
    super.new(name);
  endfunction

  // Single txn
  task send_txn();
    ahb_txn t = ahb_txn::type_id::create("t");
    start_item(t);
    
    if (!t.randomize() with {
          addr  == local::start_addr;
          write == local::do_write;
          burst == local::burst_type;
          size  == local::size;
          if (write) data[0] == local::wdata;
        })
      `uvm_error(get_type_name(), "randomize failed")
    finish_item(t);
endtask

  // Default body: just one txn (a basic read)
  task body();
    send_txn();
  endtask
endclass
// 1. Single Word Read Sequence
class ahb_single_read_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_single_read_seq)
  function new(string name = "ahb_single_read_seq");
    super.new(name);
  endfunction
endclass

// Random Reads Sequence
class ahb_rand_read_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_rand_read_seq)
  int unsigned num_txns = 15;

  function new(string name = "ahb_rand_read_seq");
    super.new(name);
  endfunction

  task body();
    for (int txn_idx = 0; txn_idx < num_txns; txn_idx++) begin
      `uvm_info(get_type_name(), $sformatf("Starting transaction %0d", txn_idx), UVM_LOW)
      assert(this.randomize() with {
        start_addr[31:20] == 12'h000;
        start_addr[1:0]   == 2'b00;
        do_write          == 0;
        burst_type        == AHB_SINGLE;
        size              == 3'b010;
      });
      send_txn();
    end
  endtask
endclass


// Incremental Burst Read Sequence (INCR4, INCR8, INCR16)
class ahb_incr_burst_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_incr_burst_seq)

  function new(string name = "ahb_incr_burst_seq");
    super.new(name);
  endfunction

  task body();
    // INCR4 burst
    start_addr = 32'h0000_0100;
    burst_type = AHB_INCR4;
    size       = 3'b010;
    do_write   = 0;
    send_txn();

    // INCR8 burst
    start_addr = 32'h0000_0200;
    burst_type = AHB_INCR8;
    send_txn();

    // INCR16 burst
    start_addr = 32'h0000_0300;
    burst_type = AHB_INCR16;
    send_txn();
  endtask
endclass


//  Wrapping Burst Read Sequence (WRAP4, WRAP8, WRAP16)
class ahb_wrap_burst_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_wrap_burst_seq)

  function new(string name = "ahb_wrap_burst_seq");
    super.new(name);
  endfunction

  task body();
    // WRAP4 word burst starting at offset 4 (boundary is 16 bytes: 0x0000_0100)
    start_addr = 32'h0000_0104;
    burst_type = AHB_WRAP4;
    size       = 3'b010;
    do_write   = 0;
    send_txn();
/*
    // WRAP8 word burst starting at offset 12 (boundary is 32 bytes: 0x0000_0200)
    start_addr = 32'h0000_020C;
    burst_type = AHB_WRAP8;
    send_txn();

    // WRAP16 word burst starting at offset 28 (boundary is 64 bytes: 0x0000_0300)
    start_addr = 32'h0000_031C;
    burst_type = AHB_WRAP16;
    send_txn();
*/
  endtask
endclass


// Cache Line Boundary and Hit Verification Sequence
class ahb_cache_test_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_cache_test_seq)

  function new(string name = "ahb_cache_test_seq");
    super.new(name);
  endfunction

  task body();
    // Beat 1: Cache miss (reads line 0x100)
    start_addr = 32'h0000_0100;
    burst_type = AHB_SINGLE;
    size       = 3'b010;
    send_txn();
/*
    // Beat 2: Cache hit (reads same line 0x104, within 16-byte line 0x100..0x10F)
    start_addr = 32'h0000_0104;
    send_txn();

    // Beat 3: Another hit in same line (0x108)
    start_addr = 32'h0000_0108;
    send_txn();

    // Beat 4: Cache miss (crosses to next cache line 0x110)
    start_addr = 32'h0000_0110;
    send_txn();
*/
  endtask
endclass


// Unaligned word address (illegal AHB-Lite). c_align is turned off on purpose.
class ahb_unaligned_read_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_unaligned_read_seq)

  function new(string name = "ahb_unaligned_read_seq");
    super.new(name);
  endfunction

  task send_unaligned(bit [31:0] a);
    ahb_txn t = ahb_txn::type_id::create("t");
    t.c_align.constraint_mode(0);
    start_item(t);
    if (!t.randomize() with {
          addr        == local::a;
          write       == 0;
          burst       == AHB_SINGLE;
          size        == 3'b010;
          addr[1:0]   != 2'b00;
        })
      `uvm_error(get_type_name(), "unaligned randomize failed")
    finish_item(t);
  endtask

  task body();
    send_unaligned(32'h0000_0101);
    send_unaligned(32'h0000_0202);
    send_unaligned(32'h0000_0303);
  endtask
endclass


// Same cache tag A[23:8], different addresses (offset and/or index)
class ahb_same_tag_diff_addr_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_same_tag_diff_addr_seq)

  function new(string name = "ahb_same_tag_diff_addr_seq");
    super.new(name);
  endfunction

  task body();
    do_write   = 0;
    burst_type = AHB_SINGLE;
    size       = 3'b010;

    start_addr = 32'h0000_0100;
    send_txn();

    start_addr = 32'h0000_0104;
    send_txn();

    start_addr = 32'h0000_0110;
    send_txn();

    start_addr = 32'h0000_0120;
    send_txn();
  endtask
endclass
















































// 2. Single Write Sequence
class ahb_single_write_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_single_write_seq)
  function new(string name = "ahb_single_write_seq");
    super.new(name);
  endfunction

  task body();
    do_write = 1;
    send_txn();
  endtask
endclass


// 8. Constrained-Random Full Stress Sequence
class ahb_rand_stress_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_rand_stress_seq)
  int unsigned num_txns = 25;

  function new(string name = "ahb_rand_stress_seq");
    super.new(name);
  endfunction

  task body();
    repeat (num_txns) begin
      ahb_burst_e b_sel;
      void'(std::randomize(b_sel) with {
        b_sel inside {AHB_SINGLE, AHB_INCR4, AHB_WRAP4, AHB_INCR8, AHB_WRAP8};
      });

      assert(this.randomize() with {
        start_addr[31:16] == 16'h0000;
        start_addr[1:0]   == 2'b00; // aligned
        do_write          == 0;
        burst_type        == b_sel;
        size              == 3'b010;
      });
      send_txn();
    end
  endtask
endclass



















// 6. Multiple Reads with Idle Cycles
class ahb_idle_interspersed_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_idle_interspersed_seq)
  int unsigned num_txns = 10;

  function new(string name = "ahb_idle_interspersed_seq");
    super.new(name);
  endfunction

  task body();
    for (int i = 0; i < num_txns; i++) begin
      start_addr = 32'h0000_0040 + (i * 16);
      burst_type = AHB_SINGLE;
      size       = 3'b010;
      do_write   = 0;
      send_txn();
    end
  endtask
endclass


// 7. Write and Readback Sequence (for config register access verification)
class ahb_wr_rdback_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_wr_rdback_seq)
  rand bit [31:0] addr;
  rand bit [31:0] data;

  function new(string name = "ahb_wr_rdback_seq");
    super.new(name);
  endfunction

  task body();
    do_write   = 1;
    start_addr = addr;
    wdata      = data;
    send_txn();  // write

    do_write   = 0;
    start_addr = addr;
    send_txn();  // readback
  endtask
endclass


