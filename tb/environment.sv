class qspi_xip_env extends uvm_env;
  `uvm_component_utils(qspi_xip_env)

  qspi_xip_env_cfg env_cfg;

  ahb_agent            ahb_agt;
  qspi_agent           qspi_agt;
  qspi_xip_scoreboard  sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(qspi_xip_env_cfg)::get(this, "", "env_cfg", env_cfg))
      `uvm_fatal(get_type_name(), "env_cfg not set by the test")

    if (env_cfg.has_ahb_agent) begin
      if (env_cfg.ahb_cfg_h == null)
        `uvm_fatal(get_type_name(), "has_ahb_agent=1 but ahb_cfg_h is null")
      uvm_config_db#(ahb_cfg)::set(this, "ahb_agt*", "cfg", env_cfg.ahb_cfg_h);
      ahb_agt = ahb_agent::type_id::create("ahb_agt", this);
    end

    if (env_cfg.has_qspi_agent) begin
      if (env_cfg.qspi_cfg_h == null)
        `uvm_fatal(get_type_name(), "has_qspi_agent=1 but qspi_cfg_h is null")
      uvm_config_db#(qspi_cfg)::set(this, "qspi_agt*", "cfg", env_cfg.qspi_cfg_h);
      qspi_agt = qspi_agent::type_id::create("qspi_agt", this);
    end

    if (env_cfg.has_scoreboard && env_cfg.has_ahb_agent && env_cfg.has_qspi_agent) begin
      uvm_config_db#(qspi_cfg)::set(this, "sb", "qcfg", env_cfg.qspi_cfg_h);
      sb = qspi_xip_scoreboard::type_id::create("sb", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (ahb_agt != null && sb != null)
      ahb_agt.mon.ap.connect(sb.ahb_export);
    if (qspi_agt != null && sb != null)
      qspi_agt.mon.ap.connect(sb.qspi_export);
  endfunction

endclass

