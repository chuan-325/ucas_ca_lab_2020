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
reg [ 3:0] arid_r  ; // ar
reg [31:0] araddr_r;
reg [ 2:0] arsize_r;
reg [31:0] awaddr_r; // aw
reg [ 2:0] awsize_r;
reg [31:0] wdata_r ; // w
reg [ 3:0] wstrb_r ;

// sram buffer


// for convenience
wire        inst_rd_req;
wire        data_rd_req;
wire        data_wt_req;
wire        inst_rd_rcv;
wire        data_rd_rcv;
wire        data_wt_rcv;

wire [ 2:0] inst_size_t;
wire [ 2:0] data_size_t;


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
        arid_r[0]<= 1'b0;
        araddr_r <= 32'b0;
        arsize_r <= 3'b0;
    end
    else if (!state_ar && data_rd_req) begin
        state_ar <= WORK;
        arid_r[0]<= 1'b0;
        araddr_r <= data_addr;
        arsize_r <= data_size_t;
    end
    else if (!state_ar && inst_rd_req) begin
        state_ar <= WORK;
        arid_r[0]<= 1'b0;
        araddr_r <= inst_addr;
        arsize_r <= inst_size_t;
    end
    else if (state_ar && arvalid && arready) begin
        state_ar <= IDLE;
        arid_r[0]<= 1'b0;
        araddr_r <= 32'b0;
        arsize_r <= 3'b0;
    end
end
always @(posedge clk) begin
    if (!resetn) begin
        state_aw <= IDLE;
        awaddr_r <= 32'b0;
        awsize_r <= 3'b0;
    end
    else if (!state_aw && !state_w && data_wt_req) begin
        state_aw <= WORK;
        awaddr_r <= data_addr;
        awsize_r <= data_size;
    end
    else if (state_aw && awvalid && awready) begin
        state_aw <= IDLE;
        awaddr_r <= 32'b0;
        awsize_r <= 3'b0;
    end

    if (!resetn) begin
        state_w <= IDLE;
        wdata_r <= 32'b0;
        wstrb_r <= 4'b0;
    end
    else if (!state_w && !state_w && data_wt_req) begin
        state_w <= WORK;
        wdata_r <= data_wdata;
        wstrb_r <= data_wstrb;
    end
    else if (state_w && wvalid && wready) begin
        state_w <= IDLE;
        wdata_r <= 32'b0;
        wstrb_r <= 4'b0;
    end
end

// CONVENIENCE
assign inst_rd_req = inst_req    & ~inst_wr;
assign data_rd_req = data_req    & ~data_wr;
assign data_wt_req = data_req    &  data_wr;
assign inst_rd_rcv = inst_rd_req &  inst_addr_ok;
assign data_rd_rcv = data_rd_req &  data_addr_ok;
assign data_wt_rcv = data_wt_req &  data_addr_ok;

/*
 |  _size  |  _size_t  |  byte  |
 |     00  |      001  |     1  |
 |     01  |      010  |     2  |
 |     10  |      100  |     4  |
*/
assign inst_size_t = {inst_size, ~|inst_size};
assign data_size_t = {data_size, ~|data_size};

endmodule
