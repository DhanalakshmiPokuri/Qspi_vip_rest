package tb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ahb_pkg::*;
  import qspi_pkg::*;

  `uvm_analysis_imp_decl(_ahb)      // move imp_decl INSIDE pkg (fixes scoreboard error)
  `uvm_analysis_imp_decl(_qspi)

  `include "scoreboard.sv"
  `include "qspi_xip_env_cfg.sv"
  `include "environment.sv"

  `include "qspi_xip_base_test.sv"
endpackage


