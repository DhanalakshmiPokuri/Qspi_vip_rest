class qspi_driver extends uvm_driver #(qspi_txn);

  `uvm_component_utils(qspi_driver)

  qspi_cfg         cfg;
  qspi_flash_model fmem;
  virtual qspi_if  vif;

  // Tracks XiP Continuous Read Mode (0xA5 mode)
  bit continuous_mode = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(qspi_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "cfg not set")
    vif  = cfg.vif;
    fmem = qspi_flash_model::type_id::create("fmem");
    fmem.preload_pattern();
  endfunction

task run_phase(uvm_phase phase);
    vif.din = 4'bz;
    fork
      reset_handler();
      forever begin
        wait (vif.rst_n === 1'b1);
        respond_to_txn();
      end
    join
  endtask

  // Main responder: waits for CS# low, decodes opcode/address, drives data
  task respond_to_txn();
    bit [7:0]  cmd;
    bit [23:0] addr;
    bit [7:0]  mode;
    int        dummy;
    int        nbytes = cfg.data_bytes;

    vif.din = 4'bz;

    // 1) Wait for CS# to go LOW (transaction starts)
    @(negedge vif.cs_n);

    // If in Continuous Read Mode, the DUT skips the 8-bit command byte and directly outputs address
    if (continuous_mode) begin
      `uvm_info(get_type_name(), "Executing Continuous Read Mode (no command byte)", UVM_HIGH)
      read_addr_quad(addr);
      read_mode_quad(mode);
      if (mode != 8'hA5) begin
        `uvm_info(get_type_name(), $sformatf("Exiting Continuous Read Mode (mode=0x%02h)", mode), UVM_MEDIUM)
        continuous_mode = 0;
      end
      dummy = (cfg.dummy_cycles > 0) ? cfg.dummy_cycles : 4;
      repeat (dummy) 
      @(posedge vif.sclk);
      drive_data_quad(addr, nbytes);
    end
    else begin
      // Decode command byte: 8 clocks 1 bit/clock on dout[0] (MSB first)
      cmd = 8'h0;
      repeat (8) begin
        @(posedge vif.sclk);
        cmd = {cmd[6:0], vif.dout[0]};
      end

      case (cmd)
        8'h66: begin // Reset Enable
          `uvm_info(get_type_name(), "Received Reset Enable (0x66)", UVM_MEDIUM)
          @(posedge vif.cs_n);
        end

        8'h99: begin // Reset Memory
          `uvm_info(get_type_name(), "Received Reset Memory (0x99) - resetting continuous mode", UVM_MEDIUM)
          continuous_mode = 0;
          @(posedge vif.cs_n);
        end

        8'h03: begin // Standard Read
          read_addr_single(addr);
          drive_data_single(addr, nbytes);
        end

        8'h0B: begin // Fast Read
          read_addr_single(addr);
          dummy = cfg.dummy_cycles;
          repeat (dummy) @(posedge vif.sclk);
          drive_data_single(addr, nbytes);
        end

        8'hEB: begin // Quad I/O Fast Read
          read_addr_quad(addr);
          read_mode_quad(mode);
          if (mode == 8'hA5) begin
            `uvm_info(get_type_name(), "Entering Continuous Read Mode (mode=0xA5)", UVM_MEDIUM)
            continuous_mode = 1;
          end
          dummy = (cfg.dummy_cycles > 0) ? cfg.dummy_cycles : 4;
          repeat (dummy) @(posedge vif.sclk);
          drive_data_quad(addr, nbytes);
        end

        default: begin
          `uvm_warning(get_type_name(),
            $sformatf("Unsupported command 0x%02h waiting for CS# high", cmd))
          @(posedge vif.cs_n);
        end
      endcase
    end

    // Wait for CS# HIGH (transaction ends)
    if (vif.cs_n === 1'b0)
      @(posedge vif.cs_n);

    // Release data lines
    vif.din = 4'bz;
  endtask

 task reset_handler();
    forever begin
      @(negedge vif.rst_n);
      continuous_mode = 0;
      `uvm_info(get_type_name(), "Reset asserted: clearing continuous mode", UVM_MEDIUM)
    end
  endtask

  // Address capture helpers (Sample DUT outputs on vif.dout)
  task read_addr_single(output bit [23:0] a);
    a = 0;
    repeat (24) begin
      @(posedge vif.sclk);
      a = {a[22:0], vif.dout[0]};
    end
  endtask

  task read_addr_quad(output bit [23:0] a);
    a = 0;
    repeat (6) begin
      @(posedge vif.sclk);
      a = (a << 4) | {vif.dout[3], vif.dout[2], vif.dout[1], vif.dout[0]};
    end
  endtask

  task read_mode_quad(output bit [7:0] m);
    m = 0;
    repeat (2) begin
      @(posedge vif.sclk);
      m = (m << 4) | {vif.dout[3], vif.dout[2], vif.dout[1], vif.dout[0]};
    end
  endtask

  // Data drive helpers (Drive flash outputs to DUT via vif.din)
  task drive_data_single(bit [23:0] addr, int nbytes);
    for (int i = 0; i < nbytes; i++) begin
      bit [7:0] d = fmem.read_byte(addr + i);
      repeat (8) begin
        @(negedge vif.sclk);
        vif.din[1] = d[7];
        d = d << 1;
      end
    end
    @(negedge vif.sclk);
    vif.din = 4'bz;
  endtask

  task drive_data_quad(bit [23:0] addr, int nbytes);
    for (int i = 0; i < nbytes; i++) begin
      bit [7:0] d = fmem.read_byte(addr + i);
      @(negedge vif.sclk);
      vif.din = d[7:4];    // MS nibble on din[3:0]
      @(negedge vif.sclk);
      vif.din = d[3:0];    // LS nibble on din[3:0]
    end
    @(negedge vif.sclk);
    vif.din = 4'bz;        // release after data transfer
  endtask

endclass

