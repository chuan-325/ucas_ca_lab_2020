module cpu_axi_interface(
    input         clk         ,
    input         resetn      ,

    /* sram slave */
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

    /* axi master */
    // ar: read request
    output [ 3:0] arid        , // 0=INST, 1=DATA
    output [31:0] araddr      ,
    output [ 7:0] arlen       ,    // fixed
    output [ 2:0] arsize      ,
    output [ 1:0] arburst     ,    // fixed
    output [ 1:0] arlock      ,    // fixed
    output [ 3:0] arcache     ,    // fixed
    output [ 2:0] arprot      ,    // fixed
    output        arvalid     ,
    input         arready     ,
    //  r: read response
    input  [ 3:0] rid         , // 0=INST, 1=DATA
    input  [31:0] rdata       ,
    input  [ 1:0] rresp       ,    // ignore
    input         rlast       ,    // ignore
    input         rvalid      ,
    output        rready      ,

    // aw: write request
    output [ 3:0] awid        ,    // fixed
    output [31:0] awaddr      ,
    output [ 7:0] awlen       ,    // fixed
    output [ 2:0] awsize      ,
    output [ 1:0] awburst     ,    // fixed
    output [ 1:0] awlock      ,    // fixed
    output [ 1:0] awcache     ,    // fixed
    output [ 2:0] awprot      ,    // fixed
    output        awvalid     ,
    input         awready     ,
    //  w: write data
    output [ 3:0] wid         ,    // fixed
    output [31:0] wdata       ,
    output [ 3:0] wstrb       ,
    output        wlast       ,    // fixed
    output        wvalid      ,
    input         wready      ,
    //  b: write response
    input  [ 3:0] bid         ,    // ignore
    input  [ 1:0] bresp       ,    // ignore
    input         bvalid      ,
    output        bready     );

/**************** DECLARATION ****************/

localparam IDLE   = 1'b0;
localparam WORK   = 1'b1;

// state machine
reg        state_ar;
reg        state_r ;
reg        state_aw;
reg        state_w ;
reg        state_b ;

// axi buffer
reg        arid_r  ; // ar
reg        araddr_r;
reg        arsize_r;
reg        awaddr_r; // aw
reg        awsize_r;
reg        wdata_r ; // w
reg        wstrb_r ;

// sram buffer


// for convenience
wire       inst_rd_req;
wire       data_rd_req;
wire       data_wt_req;
wire       inst_rd_rcv;
wire       data_rd_rcv;
wire       data_wt_rcv;




/**************** LOGIC ****************/
/*
 * [ar] addr, size, valid-ready
 * [ r] id, rdata, valid-ready
 * [aw] addr, size, valid-ready
 * [ w] wdata, strb, valid-ready
 * [ b] valid-ready
 */


/**** OUTPUT ****/
// inst sram
//*assign inst_addr_ok = ;
//*assign inst_data_ok = ;
//*assign inst_rdata   = ;
// data sram
//*assign data_addr_ok = ;
//*assign data_data_ok = ;
//*assign data_rdata   = ;
// ar
//*assign arid    = ;
//*assign araddr  = ;
assign arlen   = 8'b0;
//*assign arsize  = ;
assign arburst = 2'b01;
assign arlock  = 1'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;
//*assign arvalid = ;
// r
//*assign rready  = ;
// aw
assign awid    = 4'b1;
//!assign awaddr  = {32{data_req & data_wr}} & data_addr;
assign awlen   = 8'b0;
//!assign awsize  = { 3{data_req & data_wr}} & data_size;
assign awburst = 2'b01;
assign awlock  = 1'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;
//*assign awvalid = ;
// w
assign wid     = 4'b1;
//*assign wdata   = ;
//*assign wstrb   = ;
assign wlast   = 1'b1;
//*assign wvalid  = ;
// b
//*assign bready  = ;

/**** SRAM SLAVE (from CPU-core) ****/
// GENERAL
assign inst_rd_req = inst_req    & ~inst_wr;
assign data_rd_req = data_req    & ~data_wr;
assign data_wt_req = data_req    &  data_wr;
assign inst_rd_rcv = inst_rd_req &  inst_addr_ok;
assign data_rd_rcv = data_rd_req &  data_addr_ok;
assign data_wt_rcv = data_wt_req &  data_addr_ok;

// READ
//   inst sram

//   data sram


// WRITE (data sram)




/**** AXI MASTER (to AXI-slave) ****/
// READ
//   ar

//    r

// WRITE
//   aw

//    w

//    b


// STATE machines
always @(posedge clk) begin
    if (!resetn) begin
        state_ar <= IDLE;
    end
    else if (!state_ar ) begin//TODO
        state_ar <= WORK;
    end
    else if (state_ar && arvalid) begin//TODO
        state_ar <= IDLE;
    end
end
always @(posedge clk) begin
    if (!resetn) begin
        state_r <= IDLE;
    end
    else if (!state_ar ) begin//TODO
        state_r <= WORK;
    end
    else if (state_ar && arvalid) begin//TODO
        state_r <= IDLE;
    end
end
always @(posedge clk) begin
    if (!resetn) begin
        state_aw <= IDLE;
    end
    else if (!state_ar ) begin//TODO
        state_aw <= WORK;
    end
    else if (state_ar && arvalid) begin//TODO
        state_aw <= IDLE;
    end
end
always @(posedge clk) begin
    if (!resetn) begin
        state_w <= IDLE;
    end
    else if (!state_ar) begin//TODO
        state_w <= WORK;
    end
    else if (state_ar && arvalid) begin//TODO
        state_w <= IDLE;
    end
end
always @(posedge clk) begin
    if (!resetn) begin
        state_b <= IDLE;
    end
    else if (!state_ar ) begin//TODO
        state_b <= WORK;
    end
    else if (state_ar && arvalid) begin//TODO
        state_b <= IDLE;
    end
end


endmodule