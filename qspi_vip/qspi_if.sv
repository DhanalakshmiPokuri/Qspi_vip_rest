interface qspi_if (input logic sclk, input logic rst_n);
  logic       cs_n;      // = ce_n from DUT
  logic [3:0] dout;      // DUT ? flash (driven when douten=1)
  logic [3:0] douten;    // DUT output enable per lane
  logic [3:0] din;       // flash ? DUT (VIP drives)

  // VIP (flash model) drives din based what DUT sends on dout
 // Data sampling: DUT samples din on sclk edges; VIP launches on opposite edge
endinterface

