module cpu_axi_interface(
    input         clk         ,
    input         resetn      ,

    /* inst sram */
    // master: cpu, slave: interface
    // input: master->slave, output: slave->master
    input         inst_req    ,
    input         inst_wr     ,
    input  [ 1:0] inst_size   ,
    input  [31:0] inst_addr   ,
    input  [ 3:0] inst_wstrb  ,
    input  [31:0] inst_wdata  ,
    output [31:0] inst_rdata  ,
    output        inst_addr_ok,
    output        inst_data_ok,

    /* data sram */
    // master: cpu, slave: interface
    // input: master->slave, output: slave->master
    input         data_req    ,
    input         data_wr     ,
    input  [ 1:0] data_size   ,
    input  [31:0] data_addr   ,
    input  [ 3:0] data_wstrb  ,
    input  [31:0] data_wdata  ,
    output [31:0] data_rdata  ,
    output        data_addr_ok,
    output        data_data_ok,

    /* axi */
    // master: interface, slave: axi
    //input: slave->master, output: master->slave
    // ar: read request
    output [ 3:0] arid        ,
    output [31:0] araddr      ,
    output [ 7:0] arlen       , // fixed, 8'b0
    output [ 2:0] arsize      ,
    output [ 1:0] arburst     , // fixed, 2'b1
    output [ 1:0] arlock      , // fixed, 2'b0
    output [ 3:0] arcache     , // fixed, 4'b0
    output [ 2:0] arprot      , // fixed, 3'b0
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
    output [ 3:0] awid        , // fixed, 4'b1
    output [31:0] awaddr      ,
    output [ 7:0] awlen       , // fixed, 8'b0
    output [ 2:0] awsize      ,
    output [ 1:0] awburst     , // fixed, 2'b1
    output [ 1:0] awlock      , // fixed, 2'b0
    output [ 1:0] awcache     , // fixed, 4'b0
    output [ 2:0] awprot      , // fixed, 3'b0
    output        awvalid     ,
    input         awready     ,
    //  w: write data
    output [ 3:0] wid         , // fixed, 4'b1
    output [31:0] wdata       ,
    output [ 3:0] wstrb       ,
    output        wlast       , // fixed, 1'b1
    output        wvalid      ,
    input         wready      ,
    //  b: write response
    input  [ 3:0] bid         , // ignore
    input  [ 1:0] bresp       , // ignore
    input         bvalid      ,
    output        bready     );

/**************** DECLARATION ****************/

// state machine
parameter ReadStart        = 3'd0;
parameter Readinst         = 3'd1;
parameter Read_data_check  = 3'd2;
parameter Readdata         = 3'd5;
parameter ReadEnd          = 3'd4;
parameter WriteStart       = 3'd4;
parameter Writeinst        = 3'd5;
parameter Writedata        = 3'd6;
parameter WriteEnd         = 3'd7;

reg [2:0] r_curstate;
reg [2:0] r_nxtstate;
reg [2:0] w_curstate;
reg [2:0] w_nxtstate;

// axi buffer
reg  [ 3:0] arid_r   ; // ar
reg  [31:0] araddr_r ;
reg  [ 2:0] arsize_r ;
reg         arvalid_r;
reg         rready_r ; // r
reg  [31:0] awaddr_r ; // aw
reg  [ 2:0] awsize_r ;
reg         awvalid_r;
reg  [31:0] wdata_r  ; // w
reg  [ 3:0] wstrb_r  ;
reg         wvalid_r ;
reg         bready_r ; // b

// sram buffer
reg  [31:0] inst_rdata_r;
reg         inst_rdata_r_valid;
reg  [31:0] data_rdata_r;
reg         data_rdata_r_valid;

// new
reg  [31:0] awaddr_t;
reg         read_wait_write;
reg         write_wait_read;

// for convenience
wire        inst_rd_req;
wire        data_rd_req;
wire        data_wt_req;

wire [ 2:0] inst_size_t;
wire [ 2:0] data_size_t;

/**************** LOGIC ****************/

/**** OUTPUT ****/
// ar
assign arid    = arid_r;
assign araddr  = araddr_r;
assign arlen   = 8'b0;
assign arsize  = arsize_r;
assign arburst = 2'b1;
assign arlock  = 1'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;
assign arvalid = arvalid_r;
// r
assign rready  = rready_r;
// aw
assign awid    = 4'b1;
assign awaddr  = awaddr_r;
assign awlen   = 8'b0;
assign awsize  = awsize_r;
assign awburst = 2'b01;
assign awlock  = 1'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;
assign awvalid = awvalid_r;
// w
assign wid     = 4'b1;
assign wdata   = wdata_r;
assign wstrb   = wstrb_r;
assign wlast   = 1'b1;
assign wvalid  = wvalid_r;
// b
assign bready  = bready_r;

// sram
assign inst_addr_ok = (r_curstate == ReadStart && r_nxtstate == Readinst)
                   || (w_curstate == WriteStart && w_nxtstate == Writeinst);
assign inst_data_ok = r_curstate == ReadEnd && arid == 4'd0;
assign data_addr_ok = (r_curstate == ReadStart && r_nxtstate == Read_data_check)
                   || (w_curstate == WriteStart && w_nxtstate == Writedata);
assign data_data_ok = (r_curstate == ReadEnd && r_nxtstate == ReadStart && arid == 4'd1)
                   || (w_curstate == WriteEnd && w_nxtstate == WriteStart)
                   || rvalid;

assign inst_rdata = inst_rdata_r;
assign data_rdata = data_rdata_r;

always@(posedge clk) begin
    if (rvalid && arid == 4'd0) begin
        inst_rdata_r <= rdata;
    end
    else begin
        data_rdata_r <= rdata;
    end
end

/**** State Machine ****/
always@(posedge clk)
begin
    if(~resetn) begin
        r_curstate <= ReadStart;
        w_curstate <= WriteStart;
    end else begin
        r_curstate <= r_nxtstate;
        w_curstate <= w_nxtstate;
    end
end

always@(*)
begin
    case(r_curstate)
        ReadStart:
        begin
            if(data_rd_req)
                r_nxtstate = Read_data_check;
            else if(inst_rd_req)
                r_nxtstate = Readinst;
            else
                r_nxtstate = r_curstate;
        end
        Readinst, Readdata:
        begin
            if(rvalid)
                r_nxtstate = ReadEnd;
            else
                r_nxtstate = r_curstate;
        end
        Read_data_check:
        begin
            if(bready && awaddr_t[31:2] == araddr[31:2])
                r_nxtstate = r_curstate;
            else
                r_nxtstate = Readdata;
        end
        ReadEnd:
        begin
            if(read_wait_write)
                r_nxtstate = r_curstate;
            else
                r_nxtstate = ReadStart;
        end
        default:
            r_nxtstate = ReadStart;
    endcase
end

always@(*)
begin
    case (w_curstate)
        WriteStart:
        begin
            if(inst_req && inst_wr)
                w_nxtstate = Writeinst;
            else if(data_wt_req)
                w_nxtstate = Writedata;
            else
                w_nxtstate = w_curstate;
        end
        Writeinst, Writedata:
        begin
            if(bvalid)
                w_nxtstate = WriteEnd;
            else
                w_nxtstate = w_curstate;
        end
        WriteEnd:
        begin
            if(write_wait_read)
                w_nxtstate = w_curstate;
            else
                w_nxtstate = WriteStart;
        end
        default:
            w_nxtstate = WriteStart;
    endcase
end


//READ
//ar
always@(posedge clk)
begin
    if (!resetn) begin
        arid_r   <= 4'd0;
        araddr_r <= 32'd0;
        arsize_r <= 3'd0;
    end else if(r_curstate == ReadStart && r_nxtstate == Readinst) begin
        arid_r   <= 4'd0;
        araddr_r <= inst_addr;
        arsize_r <= !inst_size ? 3'd1 : {inst_size, 1'b0};
    end else if(r_curstate == ReadStart && r_nxtstate == Read_data_check) begin
        arid_r   <= 4'd1;
        araddr_r <= {data_addr[31:2], 2'd0};
        arsize_r <= data_size_t;
    end else if(r_curstate == ReadEnd) begin
        araddr_r <= 32'd0;
    end
end

always@(posedge clk)
begin
    if(~resetn)
        arvalid_r <= 1'b0;
    else if(r_curstate == ReadStart && r_nxtstate == Readinst || r_curstate == Read_data_check && r_nxtstate == Readdata)
        arvalid_r <= 1'b1;
    else if(arready)
        arvalid_r <= 1'b0;
end

//r
always@(posedge clk)
begin
    if(~resetn)
        rready_r <= 1'b1;
    else if(r_nxtstate == Readinst || r_nxtstate == Read_data_check)
        rready_r <= 1'b1;
    else if(rvalid)
        rready_r <= 1'b0;
end

// WRITE
//aw
always@(posedge clk)
begin
    if(~resetn) begin
        awaddr_t   <= 32'd0;
    end else if(data_wt_req && w_curstate == WriteStart) begin
        awaddr_t   <= data_addr;
    end else if(bvalid) begin
        awaddr_t   <= 32'd0;
    end
end

always@(posedge clk)
begin
    if(w_curstate == WriteStart && w_nxtstate == Writeinst) begin
        awaddr_r <= inst_addr;
        awsize_r <= !inst_size ? 3'd1 : {inst_size, 1'b0};
    end else if(w_curstate == WriteStart && w_nxtstate == Writedata) begin
        awaddr_r <= {data_addr[31:2], 2'd0};
        awsize_r <= data_size_t;
    end
end

always@(posedge clk)
begin
    if(~resetn)
        awvalid_r <= 1'b0;
    else if(w_curstate == WriteStart && (w_nxtstate == Writeinst || w_nxtstate == Writedata))
        awvalid_r <= 1'b1;
    else if(awready)
        awvalid_r <= 1'b0;
end

//w
always@(posedge clk)
begin
    if(w_curstate == WriteStart && w_nxtstate == Writeinst) begin
        wdata_r <= inst_wdata;
        wstrb_r <= inst_wstrb;
    end
    else if(w_curstate == WriteStart && w_nxtstate == Writedata) begin
        wdata_r <= data_wdata;
        wstrb_r <= data_wstrb;
    end
end

always@(posedge clk)
begin
    if(~resetn)
        wvalid_r <= 1'b0;
    else if(w_curstate == WriteStart && (w_nxtstate == Writeinst || w_nxtstate == Writedata))
        wvalid_r <= 1'b1;
    else if(wready)
        wvalid_r <= 1'b0;
end

//b
always@(posedge clk)
begin
    if(~resetn)
        bready_r <= 1'b0;
    else if(w_nxtstate == Writeinst || w_nxtstate == Writedata)
        bready_r <= 1'b1;
    else if(bvalid)
        bready_r <= 1'b0;
end

/**** wait ****/
always@(posedge clk)
begin
    if(~resetn)
        read_wait_write <= 1'b0;
    else if(r_curstate == ReadStart && r_nxtstate == Read_data_check && bready && ~bvalid)
        read_wait_write <= 1'b1;
    else if(bvalid)
        read_wait_write <= 1'b0;
end

always@(posedge clk)
begin
    if(~resetn)
        write_wait_read <= 1'b0;
    else if(w_curstate == WriteStart && w_nxtstate == Writedata && rready && ~rvalid)
        write_wait_read <= 1'b1;
    else if(rvalid)
        write_wait_read <= 1'b0;
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

endmodule
