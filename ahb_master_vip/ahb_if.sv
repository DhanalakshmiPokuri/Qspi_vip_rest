interface ahb_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input logic HCLK
);

  logic                  HRESETN;
  logic [ADDR_WIDTH-1:0] HADDR;
  logic [1:0]            HTRANS;
  logic [2:0]            HSIZE;
  logic [2:0]            HBURST;
  logic [3:0]            HPROT;
  logic                  HWRITE;
  logic [DATA_WIDTH-1:0] HWDATA;
  logic [DATA_WIDTH-1:0] HRDATA;
  logic                  HREADYOUT;
  logic                  HREADY;
  logic                  HRESP;

  modport master (
    input  HCLK, HRESETN, HRDATA, HREADY, HRESP, HREADYOUT,
    output HADDR, HTRANS, HSIZE, HBURST, HPROT, HWRITE, HWDATA
  );

  modport monitor (
    input HCLK, HRESETN,
          HADDR, HTRANS, HSIZE, HBURST, HPROT, HWRITE,
          HWDATA, HRDATA, HREADY, HRESP, HREADYOUT
  );

  task automatic pulse_reset(int unsigned cycles = 5);
    HRESETN <= 1'b0;
    repeat (cycles) @(posedge HCLK);
    HRESETN <= 1'b1;
    @(posedge HCLK);
  endtask

endinterface

