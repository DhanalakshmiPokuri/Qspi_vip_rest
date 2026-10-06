package ahb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

typedef enum {
AHB_SINGLE,
AHB_INCR,
AHB_WRAP4,
AHB_INCR4,
AHB_WRAP8,
AHB_INCR8,
AHB_WRAP16,
AHB_INCR16
} ahb_burst_e;

typedef enum {
  AHB_IDLE,
  AHB_BUSY,
  AHB_NONSEQ,
  AHB_SEQ
} ahb_trans_e;

  `include "ahb_txn.sv"
  `include "ahb_cfg.sv"
  
  `include "ahb_driver.sv"
  `include "ahb_monitor.sv"
  `include "ahb_sequencer.sv"
  `include "ahb_agent.sv"
  `include "ahb_seq_lib.sv"
endpackage

