module EF_QSPI_XIP_CTRL #( parameter    NUM_LINES   = 16, 
                                        LINE_SIZE   = 16,
                                        RESET_CYCLES= 1023 ) 
(
    input   wire                        clk,
    input   wire                        rst_n,
    input   wire [23:0]                 addr,
    input   wire                        rd,
    output  wire                        done,
    output  wire [(LINE_SIZE*8)-1: 0]   line,      

    output  wire                        sck,
    output  wire                        ce_n,
    input   wire [3:0]                  din,
    output  wire [3:0]                  dout,
    output  wire                        douten
);

    reg         first;
    reg         d_first;


    reg         rd_rd_;
    wire        rd_done;
    wire        rst_done;

    wire        rd_sck;
    wire        rd_ce_n;
    wire [3:0]  rd_din;
    wire [3:0]  rd_dout;
    wire        rd_douten;

    wire        rst_sck;
    wire        rst_ce_n;
    wire [3:0]  rst_din;
    wire [3:0]  rst_dout;
    wire        rst_douten;

    assign      done    = rd_done;

    assign      sck     = first ? rst_sck       :   rd_sck;
    assign      ce_n    = first ? rst_ce_n      :   rd_ce_n;
    assign      dout    = first ? rst_dout      :   rd_dout;
    assign      douten  = first ? rst_douten    :   rd_douten;
    
    assign      rd_din  = din;

    always @ (posedge clk or negedge rst_n)
        if(!rst_n) 
            rd_rd_ <= 1'b0;
        else if(rst_done) 
            rd_rd_ <= 1'b1;
        else if(rd_rd_) 
            rd_rd_ <= 1'b0; 

    wire    rd_rd = d_first ? rd_rd_ : rd;

    always @ (posedge clk or negedge rst_n)
        if(!rst_n) 
            first <= 1'b1;
        else if(rst_done) 
            first <= 1'b0;

    always @ (posedge clk or negedge rst_n)
        if(!rst_n) 
            d_first <= 1'b1;
        else 
            d_first <= first;

    FLASH_READER_QSPI #(.LINE_SIZE(LINE_SIZE)) 
    READER (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .rd(rd_rd),
        .done(rd_done),
        .line(line),
        .sck(rd_sck), 
        .ce_n(rd_ce_n), 
        .din(rd_din), 
        .dout(rd_dout), 
        .douten(rd_douten)  
    );

    FLASH_RESET #(.RESET_CYCLES(RESET_CYCLES))
    RESET (
        .clk(clk),
        .rst_n(rst_n),
        .start(rd),
        .done(rst_done),
        .sck(rst_sck), 
        .ce_n(rst_ce_n), 
        .din(rst_din), 
        .dout(rst_dout), 
        .douten(rst_douten)  
    );

endmodule
