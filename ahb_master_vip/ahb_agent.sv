 class ahb_agent extends uvm_agent;
 
    `uvm_component_utils(ahb_agent)
 
    ahb_cfg       cfg;
    ahb_driver    drv;
    ahb_monitor   mon;
    ahb_sequencer sqr;
 
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
 
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(ahb_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal(get_type_name(), "cfg not set")
 
      mon = ahb_monitor::type_id::create("mon", this);
 
      if (cfg.is_active == UVM_ACTIVE) begin
        drv = ahb_driver   ::type_id::create("drv", this);
        sqr = ahb_sequencer::type_id::create("sqr", this);
      end
    endfunction
 
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (cfg.is_active == UVM_ACTIVE)
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
 
  endclass
 
