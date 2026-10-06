class qspi_xip_env_cfg extends uvm_object;
  `uvm_object_utils(qspi_xip_env_cfg)

  bit  has_ahb_agent  = 1'b1;
  bit  has_qspi_agent = 1'b1;
  bit  has_scoreboard = 1'b1;
 // time last_txn_delay = 2us;

  ahb_cfg  ahb_cfg_h;
  qspi_cfg qspi_cfg_h;

  function new(string name = "qspi_xip_env_cfg");
    super.new(name);
  endfunction

  function void create_subcfgs();
    if (ahb_cfg_h == null)
      ahb_cfg_h = ahb_cfg::type_id::create("ahb_cfg_h");
    if (qspi_cfg_h == null)
      qspi_cfg_h = qspi_cfg::type_id::create("qspi_cfg_h");
  endfunction

  function void configure();
    create_subcfgs();
    ahb_cfg_h.is_active     = UVM_ACTIVE;
    qspi_cfg_h.is_active    = UVM_ACTIVE;
    qspi_cfg_h.mode         = qspi_cfg::MODE00;
    qspi_cfg_h.cmd_type     = qspi_cfg::QUAD_READ_EB;
    qspi_cfg_h.dummy_cycles = 4;
    qspi_cfg_h.data_bytes   = 16;
  endfunction
endclass

