module ahb_protocol_checker #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input logic                  HCLK,
  input logic                  HRESETN,
  input logic [ADDR_WIDTH-1:0] HADDR,
  input logic [1:0]            HTRANS,
  input logic [2:0]            HSIZE,
  input logic [2:0]            HBURST,
  input logic [3:0]            HPROT,
  input logic                  HWRITE,
  input logic [DATA_WIDTH-1:0] HWDATA,
  input logic [DATA_WIDTH-1:0] HRDATA,
  input logic                  HREADY,
  input logic                  HRESP
);

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // A1: During reset, HTRANS must be IDLE (2'b00)
  property p_reset_idle;
    @(posedge HCLK)
    (!HRESETN) |-> (HTRANS == 2'b00);
  endproperty
  A1_RESET_IDLE: assert property (p_reset_idle)
    else `uvm_error("AHB_PROTO", "A1: HTRANS is not IDLE during reset")

  // A2: Single-master AHB-Lite does not support BUSY transfers
  property p_no_busy;
    @(posedge HCLK) disable iff (!HRESETN)
    (HREADY && HTRANS == 2'b01) |-> (1'b0);
  endproperty
  A2_NO_BUSY: assert property (p_no_busy)
    else `uvm_error("AHB_PROTO", "A2: HTRANS BUSY (2'b01) is illegal in AHB-Lite single master")

  // A3: Address alignment check: HADDR must be aligned to HSIZE
  property p_align_halfword;
    @(posedge HCLK) disable iff (!HRESETN)
    (HTRANS inside {2'b10, 2'b11} && HSIZE == 3'b001) |-> (HADDR[0] === 1'b0);
  endproperty
  A3_ALIGN_HALFWORD: assert property (p_align_halfword)
    else `uvm_error("AHB_PROTO", "A3: Halfword transfer address not aligned (HADDR[0] != 0)")

  property p_align_word;
    @(posedge HCLK) disable iff (!HRESETN)
    (HTRANS inside {2'b10, 2'b11} && HSIZE == 3'b010) |-> (HADDR[1:0] === 2'b00);
  endproperty
  A3_ALIGN_WORD: assert property (p_align_word)
    else `uvm_error("AHB_PROTO", "A3: Word transfer address not aligned (HADDR[1:0] != 00)")

  // A4: Address and control signals must remain stable during wait states (HREADY == 0)
/*
  property p_ctrl_stable_during_wait;
    @(posedge HCLK) disable iff (!HRESETN)
    (!HREADY && $past(HTRANS inside {2'b10, 2'b11})) |-> 
      $stable(HADDR) && $stable(HTRANS) && $stable(HSIZE) && $stable(HBURST) && $stable(HWRITE);
  endproperty
  A4_CTRL_STABLE_DURING_WAIT: assert property (p_ctrl_stable_during_wait)
    else `uvm_error("AHB_PROTO", "A4: Master changed address/control signals during slave wait state (HREADY=0)")
*/
  // A5: HTRANS SEQ (2'b11) is only valid after NONSEQ or SEQ
  property p_seq_continuation; 
    @(posedge HCLK) disable iff (!HRESETN)
    (HREADY && HTRANS == 2'b11) |-> $past(HTRANS inside {2'b10, 2'b11});
  endproperty
  A5_SEQ_CONTINUATION: assert property (p_seq_continuation)
    else `uvm_error("AHB_PROTO", "A5: HTRANS SEQ occurred without preceding NONSEQ or SEQ")

  // A6: Address must not have X/Z during active transfer phase
  property p_addr_known;
    @(posedge HCLK) disable iff (!HRESETN)
    (HTRANS inside {2'b10, 2'b11}) |-> !$isunknown(HADDR);
  endproperty
  A6_ADDR_KNOWN: assert property (p_addr_known)
    else `uvm_error("AHB_PROTO", "A6: HADDR contains unknown/X bits during active transfer")

endmodule

