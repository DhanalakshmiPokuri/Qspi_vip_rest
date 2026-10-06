module tb_top;
  import uvm_pkg::*;
  import tb_pkg::*;
  `include "uvm_macros.svh"

  logic hclk = 0;
  logic hsel = 1'b1;

  always #5ns hclk = ~hclk;          // 100 MHz (10ns period)

  ahb_if  ahb_vif  (.HCLK(hclk));
  qspi_if qspi_vif (.sclk(),.rst_n(ahb_vif.HRESETN));

  initial begin
    ahb_vif.HRESETN = 1'b0;
    repeat (5) 
    @(posedge hclk);
    ahb_vif.HRESETN = 1'b1;
  end

  EF_QSPI_XIP_CTRL_AHBL #(
    .NUM_LINES (16),.LINE_SIZE (16),.RESET_CYCLES(25)
  ) dut (
    .HCLK      (hclk),
    .HRESETn   (ahb_vif.HRESETN),
    .HSEL      (hsel),
    .HADDR     (ahb_vif.HADDR),
    .HTRANS    (ahb_vif.HTRANS),
    .HWRITE    (ahb_vif.HWRITE),
    .HREADY    (ahb_vif.HREADY),
    .HREADYOUT (ahb_vif.HREADYOUT),
    .HRDATA    (ahb_vif.HRDATA),
    .sck       (qspi_vif.sclk), //sclk comes from dut
    .ce_n      (qspi_vif.cs_n),
    .din       (qspi_vif.din),
    .dout      (qspi_vif.dout),
    .douten    (qspi_vif.douten)
  );

  assign ahb_vif.HREADY = ahb_vif.HREADYOUT;

  ahb_protocol_checker #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32)
  ) ahb_chk (
    .HCLK    (hclk),
    .HRESETN (ahb_vif.HRESETN),
    .HADDR   (ahb_vif.HADDR),
    .HTRANS  (ahb_vif.HTRANS),
    .HSIZE   (ahb_vif.HSIZE),
    .HBURST  (ahb_vif.HBURST),
    .HPROT   (ahb_vif.HPROT),
    .HWRITE  (ahb_vif.HWRITE),
    .HWDATA  (ahb_vif.HWDATA),
    .HRDATA  (ahb_vif.HRDATA),
    .HREADY  (ahb_vif.HREADY),
    .HRESP   (ahb_vif.HRESP)
  );

  qspi_checker qspi_chk (
    .sclk    (qspi_vif.sclk),
    .rst_n   (ahb_vif.HRESETN),
    .cs_n    (qspi_vif.cs_n),
    .dout    (qspi_vif.dout),
    .douten  (qspi_vif.douten),
    .din     (qspi_vif.din)
  );

  initial begin
    uvm_config_db#(virtual ahb_if)::set(null, "*", "ahb_vif", ahb_vif);
    uvm_config_db#(virtual qspi_if)::set(null, "*", "qspi_vif",qspi_vif);
    run_test();
  end

 // initial begin
   // #10ms;
    //`uvm_fatal("TB_TOP", " timeout simulation kill")
 // end

endmodule

