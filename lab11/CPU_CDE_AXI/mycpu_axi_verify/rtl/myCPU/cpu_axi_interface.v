module cpu_axi_interface(
    input         clk         ,
    input         resetn      ,

    /* as slave to mycpu */
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

    /* as master to axi crossbar */
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

/* DECLARATION */

localparam IDLE   = 1'b0;
localparam WORK   = 1'b1;

wire rd_req;
wire wt_req;
wire inst_rd_shkhd;
wire data_rd_shkhd;
wire data_wt_shkhd;
reg  inst_req_r;
reg  data_req_r;

reg  rd_txn   ; // txn = transaction
reg  wt_txn   ;
wire arshkhd  ;
wire rshkhd   ;
wire awshkhd  ;
wire wshkhd   ;
wire bshkhd   ;
reg  awshkhd_r;
reg  wshkhd_r ;

reg  STATE_ar ;
reg  STATE_r  ;
reg  STATE_aww;
reg  STATE_b  ;

reg [ 3:0] arid_r  ;
reg [31:0] araddr_r;
reg [ 2:0] arsize_r;
reg [31:0] awaddr_r;
reg [ 2:0] awsize_r;
reg [31:0] wdata_r ;
reg [ 3:0] wstrb_r ;

/* LOGIC */

assign rd_req = inst_req & ~inst_wr
              | data_req & ~data_wr;
assign wt_req = data_req &  data_wr;

assign inst_rd_shkhd = inst_req & inst_addr_ok & ~inst_wr;
assign data_rd_shkhd = data_req & data_addr_ok & ~data_wr;
assign data_wt_shkhd = data_req & data_addr_ok &  data_wr;

always @(posedge clk) begin
    if (!resetn) begin
        rd_txn <= 1'b0;
    end
    else if (!rd_txn && !wt_txn
           && rd_req && !wt_req) begin
        rd_txn <= 1'b1;
    end
    else if (rshkhd) begin
        rd_txn <= 1'b0;
    end
end
always @(posedge clk) begin
    if (!resetn) begin
        wt_txn <= 1'b0;
    end
    else if (!wt_txn && !rd_txn
           && wt_req && !rd_req) begin
        wt_txn <= 1'b1;
    end
    else if (bshkhd) begin
        wt_txn <= 1'b0;
    end
end

assign arshkhd = arvalid & arready;
assign rshkhd  = rvalid  & rready ;
assign awshkhd = awvalid & awready;
assign wshkhd  = wvalid  & wready ;
assign bshkhd  = bvalid  & bready ;

/* OUTPUT */
// inst sram
assign inst_addr_ok = !rd_txn && !wt_txn && !data_req && inst_req;
assign inst_data_ok =  inst_req_r && rd_txn && rshkhd;
assign inst_rdata   = {32{inst_req_r}} & rdata;
// data sram
assign data_addr_ok = !rd_txn && !wt_txn && !inst_req && data_req;
assign data_data_ok =  data_req_r && (rd_txn && rshkhd
                                    ||wt_txn && bshkhd);
assign data_rdata   = {32{data_req_r}} & rdata;
// ar
assign arid    = arid_r;
assign araddr  = araddr_r;
assign arlen   = 8'b0;
assign arsize  = arsize_r;
assign arburst = 2'b01;
assign arlock  = 1'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;
assign arvalid = (STATE_ar == IDLE) && rd_txn;
// r
assign rready  = (STATE_ar == WORK) && rd_txn;
// aw
assign awid    = 4'b1;
assign awaddr  = {32{data_req & data_wr}} & data_addr;
assign awlen   = 8'b0;
assign awsize  = { 3{data_req & data_wr}} & data_size;
assign awburst = 2'b01;
assign awlock  = 1'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;
assign awvalid = !awshkhd_r && wt_txn;
// w
assign wid     = 4'b1;
assign wdata   = {32{data_req & data_wr}} & data_wdata;
assign wstrb   = { 4{data_req & data_wr}} & data_wstrb;
assign wlast   = 1'b1;
assign wvalid  = !wshkhd && wt_txn;
// b
assign bready  = (STATE_aww == WORK) && wt_txn;

/* FSM */
// ar
always @(posedge clk) begin
    if (!resetn) begin
        STATE_ar <= IDLE;
    end
    else if (arshkhd && (STATE_ar == IDLE)) begin
        STATE_ar <= WORK;
    end
    else if (rshkhd && (STATE_ar == WORK)) begin
        STATE_ar <= IDLE;
    end
end
// r
always @(posedge clk) begin
    if (!resetn) begin
        STATE_r <= IDLE;
    end
    else if (rshkhd) begin
        STATE_r <= WORK;
    end
    else if (arshkhd) begin
        STATE_r <= IDLE;
    end
end
// aww
always @(posedge clk) begin
    if (!resetn) begin
        STATE_aww <= IDLE;
    end
    else if (awshkhd||wshkhd) begin
        STATE_aww <= WORK;
    end
    else if (bshkhd) begin
        STATE_aww <= IDLE;
    end

    if (!resetn) begin
        awshkhd_r <= 1'b0;
        wshkhd_r  <= 1'b0;
    end
    else if (awshkhd||wshkhd) begin
        awshkhd_r <= awshkhd;
        wshkhd_r  <= wshkhd;
    end
    else if (bshkhd) begin
        awshkhd_r <= 1'b0;
        wshkhd_r  <= 1'b0;
    end
end
// b
always @(posedge clk) begin
    if (!resetn) begin
        STATE_b <= IDLE;
    end
    else if (wlast && wshkhd) begin
        STATE_b <= WORK;
    end
    else if (bshkhd) begin
        STATE_b <= IDLE;
    end
end

/* BUF */
always @(posedge clk) begin
    if (!resetn) begin
        inst_req_r <= 1'b0;
    end
    else if (inst_rd_shkhd) begin
        inst_req_r <= inst_req;
    end
end
always @(posedge clk) begin
    if (!resetn) begin
        data_req_r <= 1'b0;
    end
    else if (data_rd_shkhd||data_wt_shkhd) begin
        data_req_r <= data_req;
    end
end
// ar
always @(posedge clk) begin
    if (!resetn) begin
        arid_r   <=  4'b0;
        araddr_r <= 32'b0;
        arsize_r <=  3'b0;
    end
    else if (data_rd_shkhd) begin
        arid_r   <= 4'b1;
        araddr_r <= data_addr;
        arsize_r <= data_size;
    end
    else if (inst_rd_shkhd) begin
        arid_r   <= 4'b0;
        araddr_r <= inst_addr;
        arsize_r <= inst_size;
    end
end
// aw
always @(posedge clk) begin
    if (!resetn) begin
        awaddr_r <= 32'b0;
        awsize_r <=  3'b0;
    end
    else if (data_wt_shkhd) begin
        awaddr_r <= data_addr;
        awsize_r <= data_size;
    end
end
// w
always @(posedge clk) begin
    if (!resetn) begin
        wdata_r <= 32'b0;
        wstrb_r <=  4'b0;
    end
    else if (data_wt_shkhd) begin
        wdata_r <= data_wdata;
        wstrb_r <= data_wstrb;
    end
end

endmodule