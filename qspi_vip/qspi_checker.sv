module qspi_checker (
  input logic       sclk,
  input logic       rst_n,
  input logic       cs_n,
  input logic [3:0] dout,
  input logic [3:0] douten,
  input logic [3:0] din
);
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Q1: In SPI Mode 00 (CPOL=0), sclk must be LOW when CS# is deasserted (idle)
  property p_cpol0_idle;
    @(posedge sclk) disable iff (!rst_n)
    cs_n |-> (sclk === 1'b0);
  endproperty
  Q1_CPOL0_IDLE: assert property (p_cpol0_idle)
    else `uvm_error("QSPI_CHK", "Q1: sclk toggled while CS# was deasserted (CPOL=0 violation)")

// Q2: Mode 00 setup rule: sclk must be LOW when CS# transitions LOW
  property p_cs_setup;
    @(negedge cs_n) disable iff (!rst_n)
    (sclk === 1'b0);
  endproperty
  Q2_CS_SETUP: assert property (p_cs_setup)
    else `uvm_error("QSPI_CHK", "Q2: CS# asserted while sclk was HIGH (Mode 00 setup violation)")

// Q3: No X/Z on dout[0] when output enable is active during active CS#
  property p_dout0_known;
    @(posedge sclk) disable iff (!rst_n)
    (!cs_n && douten[0]) |-> !$isunknown(dout[0]);
  endproperty
  Q3_DOUT0_KNOWN: assert property (p_dout0_known)
    else `uvm_error("QSPI_CHK", "Q3: dout[0] is X/Z during active transfer")


  // Q5: CS# glitch prevention: once asserted LOW, must stay LOW for at least 8 sclk cycles
  property p_cs_min_active;
    @(posedge sclk) disable iff (!rst_n)
    $fell(cs_n) |=> !cs_n [*7];
  endproperty
  Q5_CS_MIN_ACTIVE: assert property (p_cs_min_active)
    else `uvm_error("QSPI_CHK", "Q5: CS# deasserted prematurely (< 8 sclk cycles)")
endmodule



