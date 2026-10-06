class qspi_xip_base_test extends uvm_test;
  `uvm_component_utils(qspi_xip_base_test)

  qspi_xip_env     env;
  qspi_xip_env_cfg env_cfg;
  virtual ahb_if   ahb_vif;
  virtual qspi_if  qspi_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void configure_env();
    env_cfg.has_ahb_agent  = 1'b1;
    env_cfg.has_qspi_agent = 1'b1;
    env_cfg.has_scoreboard = 1'b1;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env_cfg = qspi_xip_env_cfg::type_id::create("env_cfg");
    env_cfg.configure();
    configure_env();

    if (!uvm_config_db#(virtual ahb_if)::get(this,"","ahb_vif", ahb_vif))
      `uvm_fatal("NO_VIF", "ahb_vif not set")
    if (!uvm_config_db#(virtual qspi_if)::get(this,"","qspi_vif", qspi_vif))
      `uvm_fatal("NO_VIF", "qspi_vif not set")

    env_cfg.ahb_cfg_h.vif  = ahb_vif;
    env_cfg.qspi_cfg_h.vif = qspi_vif;

    uvm_config_db#(qspi_xip_env_cfg)::set(this, "env*","env_cfg", env_cfg);
    env = qspi_xip_env::type_id::create("env", this);
  endfunction
endclass


class ahb_single_read extends qspi_xip_base_test;
  `uvm_component_utils(ahb_single_read)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_single_read_seq seq;
    phase.raise_objection(this);
    seq = ahb_single_read_seq::type_id::create("seq");
    seq.start_addr = 32'h0000_0100;
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass


class multi_read_rand_addr extends qspi_xip_base_test;
  `uvm_component_utils(multi_read_rand_addr)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_rand_read_seq seq;
    phase.raise_objection(this);
    seq = ahb_rand_read_seq::type_id::create("seq");
    seq.num_txns = 15;
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass


class burst_incr_read extends qspi_xip_base_test;
  `uvm_component_utils(burst_incr_read)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_incr_burst_seq seq;
    phase.raise_objection(this);
    seq = ahb_incr_burst_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass


class burst_wrap_read extends qspi_xip_base_test;
  `uvm_component_utils(burst_wrap_read)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_wrap_burst_seq seq;
    phase.raise_objection(this);
    seq = ahb_wrap_burst_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass





class reset_during_txn extends qspi_xip_base_test;
  `uvm_component_utils(reset_during_txn)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_rand_read_seq seq;
    phase.raise_objection(this);

    seq = ahb_rand_read_seq::type_id::create("pre_rst_seq");
    seq.num_txns = 10;
    fork
      seq.start(env.ahb_agt.sqr);
      begin
        wait (env.sb.ahb_reads_checked >= 4);
        ahb_vif.pulse_reset(8);
      end
    join_any
    disable fork;

    wait (ahb_vif.HRESETN === 1'b1);
    @(posedge ahb_vif.HCLK);

    `uvm_info("TEST", "Reset deasserted: starting sequence from transaction 0", UVM_LOW)
    seq = ahb_rand_read_seq::type_id::create("post_rst_seq");
    seq.num_txns = 10;
    seq.start(env.ahb_agt.sqr);
    #1000ns;
    phase.drop_objection(this);
    
  endtask
endclass




class rand_stress_regression extends qspi_xip_base_test;
  `uvm_component_utils(rand_stress_regression)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_rand_stress_seq seq;
    phase.raise_objection(this);
    seq = ahb_rand_stress_seq::type_id::create("seq");
    seq.num_txns = 20;
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass


class illegal_ahb_transfers extends qspi_xip_base_test;
  `uvm_component_utils(illegal_ahb_transfers)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_single_read_seq seq;
    phase.raise_objection(this);
    seq = ahb_single_read_seq::type_id::create("seq");
    seq.start_addr = 32'h0000_0101;
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass


class hsel_deselected extends qspi_xip_base_test;
  `uvm_component_utils(hsel_deselected)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_single_read_seq seq;
    phase.raise_objection(this);
    seq = ahb_single_read_seq::type_id::create("seq");
    seq.start_addr = 32'h0000_0500;
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass


class multiple_reads_idle_cycles extends qspi_xip_base_test;
  `uvm_component_utils(multiple_reads_idle_cycles)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_idle_interspersed_seq seq;
    phase.raise_objection(this);
    seq = ahb_idle_interspersed_seq::type_id::create("seq");
    seq.num_txns = 8;
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass


class cache_hit_test extends qspi_xip_base_test;
  `uvm_component_utils(cache_hit_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_cache_test_seq seq;
    phase.raise_objection(this);
    seq = ahb_cache_test_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);
    #500ns;
    phase.drop_objection(this);
    
  endtask
endclass




class ahb_align_error_catcher extends uvm_report_catcher;
  int unsigned match_count;

  function new(string name = "ahb_align_error_catcher");
    super.new(name);
  endfunction

  function action_e catch();
    string msg;
    if (get_severity() == UVM_ERROR && get_id() == "AHB_PROTO") begin
      msg = get_message();
      if (uvm_re_match(".*[Aa]lign.*", msg) == 0) begin
        match_count++;
        set_severity(UVM_INFO);
        set_id("AHB_PROTO_EXPECTED");
      end
    end
    return THROW;
  endfunction
endclass


class unaligned_addr_test extends qspi_xip_base_test;
  `uvm_component_utils(unaligned_addr_test)

  ahb_align_error_catcher catcher;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void configure_env();
    super.configure_env();
    env_cfg.has_scoreboard = 1'b0;
  endfunction

  function void build_phase(uvm_phase phase);
    catcher = new("align_catcher");
    uvm_report_cb::add(null, catcher);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_unaligned_read_seq seq;
    phase.raise_objection(this);
    seq = ahb_unaligned_read_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);
    if (catcher.match_count == 0)
      `uvm_error("TEST", "Unaligned test expected AHB_PROTO alignment error, but none were seen")
    phase.drop_objection(this);
    #500ns;
  endtask
endclass


class same_tag_diff_addr extends qspi_xip_base_test;
  `uvm_component_utils(same_tag_diff_addr)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_same_tag_diff_addr_seq seq;
    phase.raise_objection(this);
    seq = ahb_same_tag_diff_addr_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass











































class xip_eb_read extends qspi_xip_base_test;
  `uvm_component_utils(xip_eb_read)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_single_read_seq seq;
    phase.raise_objection(this);
    seq = ahb_single_read_seq::type_id::create("seq");
    seq.start_addr = 32'h0000_0201;
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass


class xip_continuous_read extends qspi_xip_base_test;
  `uvm_component_utils(xip_continuous_read)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_single_read_seq seq;
    phase.raise_objection(this);

    seq = ahb_single_read_seq::type_id::create("seq1");
    seq.start_addr = 32'h0000_0100;
    seq.start(env.ahb_agt.sqr);

    seq = ahb_single_read_seq::type_id::create("seq2");
    seq.start_addr = 32'h0000_0200;
    seq.start(env.ahb_agt.sqr);

    seq = ahb_single_read_seq::type_id::create("seq3");
    seq.start_addr = 32'h0000_0300;
    seq.start(env.ahb_agt.sqr);

    phase.drop_objection(this);
    #500ns;
  endtask
endclass






class sclk_generation_check extends qspi_xip_base_test;
  `uvm_component_utils(sclk_generation_check)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_single_read_seq seq;
    phase.raise_objection(this);
    seq = ahb_single_read_seq::type_id::create("seq");
    seq.start_addr = 32'h0000_0140;
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass



class tc01_smoke_test extends ahb_single_read;
  `uvm_component_utils(tc01_smoke_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass


class rst_in_middle extends reset_during_txn;
  `uvm_component_utils(rst_in_middle)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass



class cfg_register_access extends qspi_xip_base_test;
  `uvm_component_utils(cfg_register_access)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_wr_rdback_seq seq;
    phase.raise_objection(this);
    seq = ahb_wr_rdback_seq::type_id::create("seq");
    seq.addr = 32'h0000_0004;
    seq.data = 32'hDEAD_BEEF;
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass


class ahb_backpressure extends qspi_xip_base_test;
  `uvm_component_utils(ahb_backpressure)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_single_read_seq seq;
    phase.raise_objection(this);
    seq = ahb_single_read_seq::type_id::create("seq");
    seq.start_addr = 32'h0000_0400;
    seq.start(env.ahb_agt.sqr);
    phase.drop_objection(this);
    #500ns;
  endtask
endclass

