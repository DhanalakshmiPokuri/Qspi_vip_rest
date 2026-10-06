
class ahb_driver extends uvm_driver #(ahb_txn);

  `uvm_component_utils(ahb_driver)

  ahb_cfg cfg;
  virtual ahb_if.master  vif;
  //uvm_analysis_port #(ahb_txn) item_completed_ap;

  // Prefetch FIFO for pipelining - allows lookahead to drive idle cycles correctly
  uvm_tlm_fifo#(ahb_txn)  prefetch_fifo;

  // Binary semaphore for address phase arbitration
  semaphore   addr_key;

  // Track objections raised by driver  items
  int unsigned                 active_objections;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    //item_completed_ap = new("item_completed_ap", this);
    addr_key  = new(1);
    active_objections = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ahb_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "cfg not set")
    vif  = cfg.vif;
    prefetch_fifo = new("prefetch_fifo", this, 1);
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_txn dummy;
    do_init();
    forever begin
      wait (vif.HRESETN === 1'b1);

      // Re-create binary semaphore on reset recovery so any key lost during mid-txn disable fork is restored
      addr_key = new(1);
      // Flush stale pre-reset transactions
      while (prefetch_fifo.try_get(dummy));

      fork
        // Prefetch task: gets items ahead of time for lookahead
        do_mst_prefetch(phase);
        // Two parallel pipeline threads for AHB pipelining (up to 2 transfers in flight)
        do_mst_ahb_trans(phase);
        do_mst_ahb_trans(phase);
        @(negedge vif.HRESETN);
      join_any
      disable fork;
      do_init();

      // Clean up any held objections on reset so test doesn't hang
      while (active_objections > 0) begin
       `uvm_info("AHB_DRV",$sformatf("no of objections %s ",active_objections),100)
        phase.drop_objection(this);
        active_objections--;
       `uvm_info("AHB_DRV",$sformatf("no of objections %s ",active_objections),100)
      end
    end
  endtask

  // Prefetch sequence items into FIFO and raise objection until transaction finishes on bus
  task do_mst_prefetch(uvm_phase phase);
    forever begin
      ahb_txn req;
      seq_item_port.get_next_item(req);
      phase.raise_objection(this);
      active_objections++;
      prefetch_fifo.put(req);
      seq_item_port.item_done();
    end
  endtask

  // Drive pipelined AHB transaction (supports SINGLE, INCR4/8/16, WRAP4/8/16)
  task do_mst_ahb_trans(uvm_phase phase);
    ahb_txn req;
    forever begin
      int beats;
      bit [31:0] addr;

      addr_key.get(); // lock address phase pipeline
      prefetch_fifo.get(req);

      beats = get_num_beats(req);
      if (!req.write)
        req.rd_data = new[beats];

      `uvm_info("AHB_DRV",$sformatf("Driving transaction --0x%08h burst=%0s beats=%0d",req.addr, req.burst.name(),beats),UVM_LOW)

      addr = req.addr;

      // 1. Beat 0 Address Phase
      vif.HADDR  <= addr;
      vif.HWRITE <= req.write;
      vif.HTRANS <= 2'b10; // NONSEQ
      vif.HSIZE  <= req.size;
      vif.HBURST <= req.burst;
      vif.HPROT  <= req.prot;

      wait_ready(); // wait for beat 0 address accepted

      // 2. Intermediate beats (if burst > 1 beat)
      for (int b = 1; b < beats; b++) begin
        addr = get_next_addr(req, addr);
        vif.HADDR  <= addr;
        vif.HTRANS <= 2'b11; // SEQ

        if (req.write)
          vif.HWDATA <= req.data[b-1];

        wait_ready(); // wait for beat b address / beat b-1 data accepted

        if (!req.write)
          req.rd_data[b-1] = vif.HRDATA;
      end

      // 3. All address phases of this burst are complete!
      // If no next item in FIFO, drive IDLE on bus
      if (prefetch_fifo.is_empty()) begin
        do_mst_idle();
      end

      addr_key.put(1); // unlock address phase pipeline for next transfer

      // 4. Final beat Data Phase
      if (req.write)
        vif.HWDATA <= req.data[beats-1];

      wait_ready(); // wait for final beat data accepted

      if (!req.write)
        req.rd_data[beats-1] = vif.HRDATA;

      if (req.write)
        vif.HWDATA <= '0;

  `uvm_info("AHB_DRV", $sformatf("COMPLETED: addr=0x%08h write=%0d burst=%0s data=%0p",req.addr, req.write, req.burst.name(), req.write ? req.data : req.rd_data), UVM_MEDIUM)
     // item_completed_ap.write(req);

      phase.drop_objection(this);
      if (active_objections > 0)
        active_objections--;
    end
  endtask

  // Calculate number of beats for SINGLE, INCR, and WRAP bursts
  function automatic int get_num_beats(ahb_txn req);
    case (req.burst)
      AHB_SINGLE:              return 1;
      AHB_INCR4,  AHB_WRAP4:   return 4;
      AHB_INCR8,  AHB_WRAP8:   return 8;
      AHB_INCR16, AHB_WRAP16:  return 16;
      AHB_INCR:                return (req.incr_len > 0) ? req.incr_len : 1;
      default:                 return 1;
    endcase
  endfunction

  // Calculate next address for INCR and WRAP bursts
  function automatic bit [31:0] get_next_addr(ahb_txn req, bit [31:0] curr_addr);
    bit [31:0] step = (1 << req.size); // bytes per beat (4 bytes for word) 32'd1..num_beats = 4 ...step = 4 bytes..boundary = 4 × 4 = 16 bytes
    bit [31:0] boundary;
    int num_beats;

    case (req.burst)
      AHB_WRAP4:  num_beats = 4;
      AHB_WRAP8:  num_beats = 8;
      AHB_WRAP16: num_beats = 16;
      default:    num_beats = 0; // INCR bursts do not wrap
    endcase

    if (num_beats > 0) begin
      boundary = num_beats * step; //total byte size of the wrapping region
      return (curr_addr & ~(boundary - 1)) | ((curr_addr + step) & (boundary - 1)); //this will wrap like 100c we reach it will go to 1000
    end else begin
      return curr_addr + step;
    end
  endfunction

  // Non-blocking IDLE drive on address bus
  task do_mst_idle();
    vif.HTRANS <= 2'b00; // IDLE
    vif.HADDR  <= '0;
  endtask

  task do_init();
    vif.HADDR  <= '0;
    vif.HWRITE <= 1'b0;
    vif.HTRANS <= 2'b00;
    vif.HSIZE  <= 3'b010;
    vif.HBURST <= 3'b000;
    vif.HPROT  <= 4'b0000;
    vif.HWDATA <= '0;
  endtask

  task wait_ready();
    @(posedge vif.HCLK);
    while (vif.HRESETN === 1'b1 && vif.HREADY !== 1'b1)
      @(posedge vif.HCLK);
  endtask

endclass

