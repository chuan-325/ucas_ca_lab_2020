module cpu_axi_interface(
    input         clk         ,
    input         resetn      ,

    /* interact with mycpu */
    // inst sram
    input         inst_req    ,
    input         inst_wr     ,
    input  [ 1:0] inst_size   ,
    input  [31:0] inst_addr   ,
    input  [ 3:0] inst_wstrb  ,
    input  [31:0] inst_wdata  ,
    output        inst_addr_ok,
    output        inst_data_ok,
    output [31:0] inst_rdata  ,
    // data sram
    input         data_req    ,
    input         data_wr     ,
    input  [ 1:0] data_size   ,
    input  [31:0] data_addr   ,
    input  [ 3:0] data_wstrb  ,
    input  [31:0] data_wdata  ,
    output        data_addr_ok,
    output        data_data_ok,
    output [31:0] data_rdata  ,

    /* interact with axi */
    // ar: read request
    output [ 3:0] arid        ,
    output [31:0] araddr      ,
    output [ 7:0] arlen       ,
    output [ 2:0] arsize      ,
    output [ 1:0] arburst     ,
    output [ 1:0] arlock      ,
    output [ 3:0] arcache     ,
    output [ 2:0] arprot      ,
    output        arvalid     ,
    input         arready     ,
    //  r: read response
    input  [ 3:0] rid         ,
    input  [31:0] rdata       ,
    input  [ 1:0] rresp       , // ignore
    input         rlast       , // ignore
    input         rvalid      ,
    output        rready      ,

    // aw: write request
    output [ 3:0] awid        ,
    output [31:0] awaddr      ,
    output [ 7:0] awlen       ,
    output [ 2:0] awsize      ,
    output [ 1:0] awburst     ,
    output [ 1:0] awlock      ,
    output [ 1:0] awcache     ,
    output [ 2:0] awprot      ,
    output        awvalid     ,
    input         awready     ,
    //  w: write data
    output [ 3:0] wid         ,
    output [31:0] wdata       ,
    output [ 3:0] wstrb       ,
    output        wlast       ,
    output        wvalid      ,
    input         wready      ,
    //  b: write response
    input  [ 3:0] bid         , // ignore
    input  [ 1:0] bresp       , // ignore
    input         bvalid      ,
    output        bready     );


/* ar: read request */


assign arlen   = 8'b0;

assign arburst = 2'b01;
assign arlock  = 1'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;

/* r: read response */


/* aw: write request */
assign awid    = 4'b1;

assign awlen   = 8'b0;

assign awburst = 2'b01;
assign awlock  = 1'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;

/* w: write data */
assign wid     = 4'b1;


assign wlast   = 1'b1;

/* b: write response */


endmodule