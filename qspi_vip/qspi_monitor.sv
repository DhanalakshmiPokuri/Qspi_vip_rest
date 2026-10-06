class qspi_monitor extends uvm_monitor;

  `uvm_component_utils(qspi_monitor)

  qspi_cfg         cfg;
  virtual qspi_if  vif;
  uvm_analysis_port #(qspi_txn) ap;

  // Tracks Continuous Read Mode (0xA5 mode)
  bit continuous_mode = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(qspi_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "cfg not set")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    fork
      reset_handler();
      forever begin
        collect_txn();
      end
    join
  endtask

  // Reset handler: clear continuous mode on reset assertion
  task reset_handler();
    forever begin
      @(negedge vif.rst_n);
      continuous_mode = 0;
      `uvm_info(get_type_name(), "Reset asserted: clearing continuous mode", UVM_MEDIUM)
    end
  endtask

  task collect_txn();
    qspi_txn  t = qspi_txn::type_id::create("t");
    bit [7:0] cmd;
    bit [23:0] a;
    bit [7:0]  m;

    @(negedge vif.cs_n);

    // In Continuous Read Mode, the DUT outputs address directly without opcode
    if (continuous_mode) begin
      t.cmd = 8'hEB;
      t.continuous_read = 1'b1;

      // 24-bit addr quad (6 clocks on dout[3:0])
      a = 0;
      repeat (6) begin
        @(posedge vif.sclk);
        a = (a << 4) | {vif.dout[3], vif.dout[2], vif.dout[1], vif.dout[0]};
      end
      t.addr = a;

      // 8-bit mode quad (2 clocks on dout[3:0])
      m = 0;
      repeat (2) begin
        @(posedge vif.sclk);
        m = (m << 4) | {vif.dout[3], vif.dout[2], vif.dout[1], vif.dout[0]};
      end
      t.mode_bits = m;
      if (m != 8'hA5) begin
        continuous_mode = 0;
      end

      t.dummy_cycles = (cfg.dummy_cycles > 0) ? cfg.dummy_cycles : 4;
      repeat (t.dummy_cycles) @(posedge vif.sclk);

      capture_data_quad(t);
    end
    else begin
      // Command byte driven by DUT on dout[0] (8 clocks)
      cmd = 0;
      repeat (8) begin
        @(posedge vif.sclk);
        cmd = {cmd[6:0], vif.dout[0]};
      end
      t.cmd = cmd;

      case (cmd)
        8'h66: begin
          `uvm_info(get_type_name(), "Monitored Flash Reset Enable command (0x66)", UVM_MEDIUM)
        end

        8'h99: begin
          `uvm_info(get_type_name(), "Monitored Flash Reset Memory command (0x99)", UVM_MEDIUM)
          continuous_mode = 0;
        end

        8'h03, 8'h0B: begin
          a = 0;
          repeat (24) begin
            @(posedge vif.sclk);
            a = {a[22:0], vif.dout[0]};
          end
          t.addr = a;
          t.dummy_cycles = (cmd == 8'h0B) ? cfg.dummy_cycles : 0;
          repeat (t.dummy_cycles) @(posedge vif.sclk);
          capture_data_single(t);
        end

        8'hEB: begin
          a = 0;
          repeat (6) begin
            @(posedge vif.sclk);
            a = (a << 4) | {vif.dout[3], vif.dout[2], vif.dout[1], vif.dout[0]};
          end
          t.addr = a;

          m = 0;
          repeat (2) begin
            @(posedge vif.sclk);
            m = (m << 4) | {vif.dout[3], vif.dout[2], vif.dout[1], vif.dout[0]};
          end
          t.mode_bits = m;
          t.continuous_read = (m == 8'hA5);
          if (m == 8'hA5) begin
            continuous_mode = 1;
          end

          t.dummy_cycles = (cfg.dummy_cycles > 0) ? cfg.dummy_cycles : 4;
          repeat (t.dummy_cycles) @(posedge vif.sclk);

          capture_data_quad(t);
        end

        default: ;
      endcase
    end

    if (vif.cs_n === 1'b0)
      @(posedge vif.cs_n);

    `uvm_info(get_type_name(), {"\n", t.sprint()}, UVM_HIGH)
    ap.write(t);
  endtask

    task capture_data_single(qspi_txn t);
    bit [7:0] d;
    t.data = new[cfg.data_bytes];
    for (int i = 0; i < cfg.data_bytes; i++) begin
      repeat (8) begin
        @(posedge vif.sclk);
        d = {d[6:0], vif.din[1]};
      end
      t.data[i] = d;
    end
  endtask

  task capture_data_quad(qspi_txn t);
    bit [7:0] d;
    t.data = new[cfg.data_bytes];
    for (int i = 0; i < cfg.data_bytes; i++) begin
      repeat (2) begin
        @(posedge vif.sclk);
        d = {d[3:0], vif.din[3], vif.din[2], vif.din[1], vif.din[0]};
      end
      t.data[i] = d;
    end
  endtask

endclass
