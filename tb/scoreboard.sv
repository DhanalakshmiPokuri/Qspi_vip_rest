class qspi_xip_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(qspi_xip_scoreboard)

  uvm_analysis_imp_ahb  #(ahb_txn,  qspi_xip_scoreboard) ahb_export;
  uvm_analysis_imp_qspi #(qspi_txn, qspi_xip_scoreboard) qspi_export;

  qspi_flash_model fmem;          // scoreboard's golden flash memory model
  qspi_cfg         qcfg;

  // Stats
  int ahb_reads_checked;
  int qspi_reads_seen;
  int reset_cmds_seen;
  int mismatches;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ahb_export  = new("ahb_export",  this);
    qspi_export = new("qspi_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(qspi_cfg)::get(this, "", "qcfg", qcfg))
      `uvm_fatal(get_type_name(), "qcfg not set")
    fmem = qspi_flash_model::type_id::create("fmem");
    fmem.preload_pattern();       // Same pattern as flash responder
  endfunction

  // ---------------- AHB side ----------------
  function void write_ahb(ahb_txn t);
    if (t.write) begin //for write 
      `uvm_info(get_type_name(),
        $sformatf("AHB write @0x%08h (reg access, no data check)", t.addr), UVM_MEDIUM)
      return;
    end

    check_ahb_read(t);
  endfunction

  // Check AHB read data against golden memory model
  function void check_ahb_read(ahb_txn a);
    bit [23:0] faddr = a.addr[23:0];

    for (int b = 0; b < a.rd_data.size(); b++) begin
      bit [23:0] fa  = faddr + b * 4;
      bit [31:0] exp = {fmem.read_byte(fa + 3),
                        fmem.read_byte(fa + 2),
                        fmem.read_byte(fa + 1),
                        fmem.read_byte(fa)};
      bit [31:0] act = a.rd_data[b];

      if (act !== exp) begin
        mismatches++;
        `uvm_error(get_type_name(),
          $sformatf("C1 MISMATCH: beat %0d @flash 0x%06h: got 0x%08h expected 0x%08h",
                    b, fa, act, exp))
      end else begin
        `uvm_info(get_type_name(),
          $sformatf("C1 MATCH: beat %0d @flash 0x%06h: data=0x%08h", b, fa, act), UVM_HIGH)
      end
    end

    ahb_reads_checked++;
  endfunction

  // ---------------- QSPI side ----------------
  function void write_qspi(qspi_txn t);
    // 1. Identify Flash Reset sequence (0x66 Enable Reset, 0x99 Reset Device)
    if (t.cmd inside {8'h66, 8'h99}) begin
      reset_cmds_seen++;
      `uvm_info(get_type_name(),
        $sformatf("Observed Hardware Flash Reset command: 0x%02h", t.cmd), UVM_LOW)
      return;
    end

    // 2. Normal Flash Read Transactions
    qspi_reads_seen++;

    // Command correctness (C2)
    if (t.cmd !== qcfg.get_cmd_byte()) begin
      `uvm_error(get_type_name(),
        $sformatf("C2: QSPI cmd=0x%02h, expected 0x%02h", t.cmd, qcfg.get_cmd_byte()))
    end

    // Dummy cycles check (C4)
    if (t.dummy_cycles !== qcfg.dummy_cycles && qcfg.dummy_cycles > 0) begin
      `uvm_error(get_type_name(),
        $sformatf("C4: dummy=%0d, expected %0d (cmd=0x%02h)",
                  t.dummy_cycles, qcfg.dummy_cycles, t.cmd))
    end

    // Data verification: ensure flash responded with correct data from golden model
    for (int i = 0; i < t.data.size(); i++) begin
      bit [7:0] exp_b = fmem.read_byte(t.addr + i);
      if (t.data[i] !== exp_b) begin
        mismatches++;
        `uvm_error(get_type_name(),
          $sformatf("QSPI line data mismatch @0x%06h: got 0x%02h expected 0x%02h",
                    t.addr + i, t.data[i], exp_b))
      end
    end

    `uvm_info(get_type_name(),
      $sformatf("QSPI Read verified @addr=0x%06h (%0d bytes, continuous=%0d)",
                t.addr, t.data.size(), t.continuous_read), UVM_MEDIUM)
  endfunction

  // ---------------- Summary ----------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    `uvm_info(get_type_name(),
      $sformatf("=========================================================================="), UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("SCOREBOARD SUMMARY:"), UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("  Reset commands observed : %0d", reset_cmds_seen), UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("  QSPI flash reads seen   : %0d", qspi_reads_seen), UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("  AHB read txns checked   : %0d", ahb_reads_checked), UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("  Data mismatches         : %0d", mismatches), UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("=========================================================================="), UVM_LOW)

    if (mismatches > 0)
      `uvm_error(get_type_name(), $sformatf("TEST FAILED: %0d mismatches detected", mismatches))
    else if (ahb_reads_checked == 0)
      `uvm_error(get_type_name(), "TEST FAILED: 0 AHB reads were checked")
    else
      `uvm_info(get_type_name(), "TEST PASSED: All AHB reads and QSPI accesses verified successfully!", UVM_LOW)
  endfunction

endclass

