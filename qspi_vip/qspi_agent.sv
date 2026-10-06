class qspi_agent extends uvm_agent;

  `uvm_component_utils(qspi_agent)

  qspi_cfg     cfg;
  qspi_driver  drv;
  qspi_monitor mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(qspi_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "cfg not set")
    mon = qspi_monitor::type_id::create("mon", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      drv = qspi_driver::type_id::create("drv", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

endclass

