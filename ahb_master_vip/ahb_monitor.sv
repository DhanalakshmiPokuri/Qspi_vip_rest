class ahb_monitor extends uvm_component;

  `uvm_component_utils(ahb_monitor)

  ahb_cfg cfg;
  virtual ahb_if.monitor vif;
  uvm_analysis_port #(ahb_txn) ap;

  // Semaphore to control address phase pipelining
  // Ensures only one pipeline thread captures address phase at a time
  semaphore address_phase_semaphore;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
    address_phase_semaphore = new(1);  
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ahb_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_VIF", "cfg not set")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      wait (vif.HRESETN === 1'b1);
      address_phase_semaphore = new(1);
      fork
        // Two parallel pipeline threads for AHB pipelining (up to 2 transfers in flight)
        collect_pipelined_transfer();
        collect_pipelined_transfer();
        //protocol_check();
        @(negedge vif.HRESETN);
      join_any
      disable fork;
    end
  endtask

  task collect_pipelined_transfer();
    ahb_txn req;
    bit reset_during_data = 1'b0;
    forever begin
      // Acquire semaphore to prevent race on address phase capture
      address_phase_semaphore.get();

      // Wait for new address phase (NONSEQ or SEQ with HREADY high)
      do 
      @(posedge vif.HCLK);
      while (!(vif.HRESETN === 1'b1 && vif.HREADY === 1'b1 && vif.HTRANS inside {2'b10, 2'b11}));

      // Capture address phase information
      req = ahb_txn::type_id::create("mon_txn");
      req.addr  = vif.HADDR;
      req.write = vif.HWRITE;
      req.size  = vif.HSIZE;
      req.burst = ahb_burst_e'(vif.HBURST);
      req.prot  = vif.HPROT;

      `uvm_info("AHB_MON",$sformatf("Captured address phase @0x%08h", req.addr), UVM_LOW)

      // Release semaphore - allow other pipeline thread to capture next address phase
      address_phase_semaphore.put();

      // Wait for data phase completion with reset check
      @(posedge vif.HCLK);
      while (vif.HRESETN === 1'b1 && vif.HREADY !== 1'b1) begin
        if (vif.HRESP === 1'b1)
          req.error_resp = 1'b1;
        @(posedge vif.HCLK);
      end

      // Check if reset occurred during data phase
      if (vif.HRESETN === 1'b0) begin
        reset_during_data = 1'b1;
        `uvm_info(get_type_name(),$sformatf("Reset occurred during data phase for txn @0x%08h", req.addr), UVM_LOW)
      end

      // Capture data phase only if no reset
      if (vif.HRESETN === 1'b1 && !reset_during_data) begin
        if (vif.HRESP === 1'b1)
          req.error_resp = 1'b1;
        if (req.write) begin
          req.data = new[1];
          req.data[0] = vif.HWDATA;
          `uvm_info(get_type_name(),$sformatf("Monitored AHB WRITE @0x%08h data=0x%08h", req.addr, req.data[0]), UVM_LOW)
        end else begin
          req.rd_data = new[1];
          req.rd_data[0] = vif.HRDATA;
          `uvm_info(get_type_name(),$sformatf("Monitored AHB READ @0x%08h data=0x%08h", req.addr, req.rd_data[0]), UVM_LOW)
        end
        ap.write(req);
      end else begin
        `uvm_info(get_type_name(),
          $sformatf("Dropped in-flight monitor txn @0x%08h due to reset", req.addr), UVM_LOW)
      end

      reset_during_data = 1'b0;  // Reset flag for next iteration
    end
  endtask
/*
  task protocol_check();
    forever begin
      @(posedge vif.HCLK);
      if (!vif.HRESETN) begin
        if (vif.HTRANS != 2'b00)
          `uvm_error("AHB_PROTO", "HTRANS not IDLE during reset")
      end else begin
        if (vif.HREADY === 1'b1 && vif.HTRANS == 2'b01)
          `uvm_error("AHB_PROTO", "HTRANS BUSY is illegal in AHB-Lite single master")

        if (vif.HREADY === 1'b1 && vif.HTRANS inside {2'b10, 2'b11}) begin
          if (vif.HSIZE == 3'b001 && vif.HADDR[0] !== 1'b0)
            `uvm_error("AHB_PROTO", "Halfword not aligned")
          if (vif.HSIZE == 3'b010 && vif.HADDR[1:0] !== 2'b00)
            `uvm_error("AHB_PROTO", "Word not aligned")
        end
      end
    end
  endtask
*/
endclass



