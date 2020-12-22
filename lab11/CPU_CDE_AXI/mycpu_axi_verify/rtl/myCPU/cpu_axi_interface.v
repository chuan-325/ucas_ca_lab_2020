/*
[4.2]=requirement, [4.3]= suggestion
1.[4.2-7] RAW not supported now (not sure)
2.[4.3-4] no state machine for 'r' and 'b' (state_r, state_b)
3.[4.3-6] SRAM-slave's input might has been stored, yet it do not need to be stored(?)
!!4.[4.3-8] use valid&&ready in addr_ok and data_ok
*/


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

// Gerneral
localparam INST  = 4'h0;
localparam DATA  = 4'h1;

localparam IDLE  = 2'h0;
localparam WORK  = 2'h1;
localparam BLOCK = 2'h2;

reg  [ 1:0] state_ar;
reg  [ 1:0] state_aw; // aw&w
reg  [ 1:0] state_r ;
reg  [ 1:0] state_b ;

// axi buffer
reg  [ 3:0] arid_r  ; // ar
reg  [31:0] araddr_r;
reg  [ 2:0] arsize_r;
reg  [31:0] awaddr_r; // aw
reg  [ 2:0] awsize_r;
reg  [31:0] wdata_r ; // w
reg  [ 3:0] wstrb_r ;

// sram buffer
reg  [31:0] rdata_r;
reg         rdata_r_valid;

// for convenience
wire        inst_rd_req;
wire        data_rd_req;
wire        data_wt_req;

wire [ 2:0] inst_size_t;
wire [ 2:0] data_size_t;


/**************** LOGIC ****************/

/**** OUTPUT ****/
// inst sram
assign inst_addr_ok = (state_ar==IDLE) && inst_rd_req && !data_rd_req;
assign inst_data_ok = (rid==INST) && rvalid && rready; //!error here should not be valid&&ready
assign inst_rdata   =  rdata_r_valid ? rdata_r : rdata;
// data sram
assign data_addr_ok = data_rd_req && (state_ar==IDLE)
                    ||data_wt_req && (state_aw==IDLE);
assign data_data_ok = (rid==DATA) && (rvalid && rready //!error here should not be valid&&ready
                                    ||bvalid && bready);
assign data_rdata   =  rdata_r_valid ? rdata_r : rdata;
// ar
assign arid    = arid_r;
assign araddr  = araddr_r;
assign arlen   = 8'b0;
assign arsize  = arsize_r;
assign arburst = 2'b01;
assign arlock  = 1'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;
assign arvalid = (state_ar==WORK);
// r
assign rready  = rvalid;
// aw
assign awid    = 4'b1;
assign awaddr  = awaddr_r;
assign awlen   = 8'b0;
assign awsize  = awsize_r;
assign awburst = 2'b01;
assign awlock  = 1'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;
assign awvalid = (state_aw==WORK);
// w
assign wid     = 4'b1;
assign wdata   = wdata_r;
assign wstrb   = wstrb_r;
assign wlast   = 1'b1;
assign wvalid  = (state_aw==WORK);
// b
assign bready  = bvalid;

/**** State Machine ****/
// READ
always @(posedge clk) begin
    if (!resetn) begin
        state_ar <= IDLE;
        arid_r   <= 4'b0;
        araddr_r <= 32'b0;
        arsize_r <= 3'b0;
    end
    else if ((state_ar!=WORK) && (state_aw==WORK) //! [RAW block]here not sure
           && data_rd_req && (data_addr==awaddr_r)) begin
        state_ar <= BLOCK;
    end
    else if ((state_ar!=WORK) && data_rd_req) begin
        state_ar <= WORK;
        arid_r   <= DATA;
        araddr_r <= data_addr;
        arsize_r <= data_size_t;
    end
    else if ((state_ar!=WORK) && inst_rd_req) begin
        state_ar <= WORK;
        arid_r   <= INST;
        araddr_r <= inst_addr;
        arsize_r <= inst_size_t;
    end
    else if ((state_ar==WORK) && arvalid && arready) begin
        state_ar <= IDLE;
        arid_r   <= 4'b0;
        araddr_r <= 32'b0;
        arsize_r <= 3'b0;
    end
end

// WRITE
always @(posedge clk) begin
    if (!resetn) begin // aw
        state_aw <= IDLE;
        awaddr_r <= 32'b0;
        awsize_r <= 3'b0;
        wdata_r  <= 32'b0;
        wstrb_r  <= 4'b0;
    end
    else if ((state_aw==IDLE) && data_wt_req) begin
        state_aw <= WORK;
        awaddr_r <= data_addr;
        awsize_r <= data_size;
        wdata_r  <= data_wdata;
        wstrb_r  <= data_wstrb;
    end
    else if ((state_aw==WORK) && awvalid && awready) begin
        state_aw <= IDLE;
        awaddr_r <= 32'b0;
        awsize_r <= 3'b0;
        wdata_r  <= 32'b0;
        wstrb_r  <= 4'b0;
    end
end

/**** CONVENIENCE ****/
assign inst_rd_req = inst_req & ~inst_wr;
assign data_rd_req = data_req & ~data_wr;
assign data_wt_req = data_req &  data_wr;

/*
 | _size | _size_t | byte |
 |-------|---------|------|
 |    00 |     001 |    1 |
 |    01 |     010 |    2 |
 |    10 |     100 |    4 |
*/
assign inst_size_t = {inst_size, ~|inst_size};
assign data_size_t = {data_size, ~|data_size};

always @(posedge clk) begin
    if (!resetn) begin
        rdata_r_valid <= 1'b0;
    end
    else if (!rdata_r_valid && rvalid && rready) begin
        rdata_r_valid <= 1'b1;
    end
    else if (rdata_r_valid && arvalid && arready) begin
        rdata_r_valid <= 1'b0;
    end

    if (!resetn) begin
        rdata_r <= 32'b0;
    end
    else if (!rdata_r_valid && rvalid && rready) begin
        rdata_r <= rdata;
    end
end

endmodule
