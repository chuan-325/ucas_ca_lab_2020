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
    // input: slave->master, output: master->slave
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

reg  [ 2:0] r_cstate;
reg  [ 2:0] r_nstate;
reg  [ 2:0] w_cstate;
reg  [ 2:0] w_nstate;

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
reg  [31:0] data_rdata_r;

// new
reg  [31:0] awaddr_t;
reg         read_wait_write;
reg         write_wait_read;

// for convenience
wire        arid_eq_i;
wire        arid_eq_d;

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
assign inst_addr_ok = (r_cstate == ReadStart && r_nstate == Readinst)
                   || (w_cstate == WriteStart && w_nstate == Writeinst);
assign inst_data_ok = r_cstate == ReadEnd && arid_eq_i;
assign data_addr_ok = (r_cstate == ReadStart && r_nstate == Read_data_check)
                   || (w_cstate == WriteStart && w_nstate == Writedata);
assign data_data_ok = (r_cstate == ReadEnd && r_nstate == ReadStart && arid_eq_d)
                   || (w_cstate == WriteEnd && w_nstate == WriteStart)
                   || rvalid;

assign inst_rdata = inst_rdata_r;
assign data_rdata = data_rdata_r;

always@(posedge clk) begin
    if (!resetn) begin
        inst_rdata_r <= 32'b0;
        data_rdata_r <= 32'b0;
    end
    else if (rvalid && arid_eq_d) begin
        data_rdata_r <= rdata;
    end
    else if (rvalid && arid_eq_i) begin
        inst_rdata_r <= rdata;
    end
end

/**** State Machine ****/
always@(posedge clk) begin
    if(!resetn) begin
        r_cstate <= ReadStart;
        w_cstate <= WriteStart;
    end
    else begin
        r_cstate <= r_nstate;
        w_cstate <= w_nstate;
    end
end

always@(*) begin
    case(r_cstate)
        ReadStart:
        begin
            if(data_rd_req)
                r_nstate = Read_data_check;
            else if(inst_rd_req)
                r_nstate = Readinst;
            else
                r_nstate = r_cstate;
        end
        Readinst, Readdata:
        begin
            if(rvalid)
                r_nstate = ReadEnd;
            else
                r_nstate = r_cstate;
        end
        Read_data_check:
        begin
            if(bready && awaddr_t[31:2] == araddr[31:2])
                r_nstate = r_cstate;
            else
                r_nstate = Readdata;
        end
        ReadEnd:
        begin
            if(read_wait_write)
                r_nstate = r_cstate;
            else
                r_nstate = ReadStart;
        end
        default:
            r_nstate = ReadStart;
    endcase
end

always@(*) begin
    case (w_cstate)
        WriteStart:
        begin
            if(inst_req && inst_wr)
                w_nstate = Writeinst;
            else if(data_wt_req)
                w_nstate = Writedata;
            else
                w_nstate = w_cstate;
        end
        Writeinst, Writedata:
        begin
            if(bvalid)
                w_nstate = WriteEnd;
            else
                w_nstate = w_cstate;
        end
        WriteEnd:
        begin
            if(write_wait_read)
                w_nstate = w_cstate;
            else
                w_nstate = WriteStart;
        end
        default:
            w_nstate = WriteStart;
    endcase
end


//READ
//ar
always@(posedge clk) begin
    if (!resetn) begin
        arid_r   <= 4'd0;
        araddr_r <= 32'd0;
        arsize_r <= 3'd0;
    end else if(r_cstate == ReadStart && r_nstate == Read_data_check) begin
        arid_r   <= 4'd1;
        araddr_r <= {data_addr[31:2], 2'd0};
        arsize_r <= data_size_t;
    end
    else if(r_cstate == ReadStart && r_nstate == Readinst) begin
        arid_r   <= 4'd0;
        araddr_r <= inst_addr;
        arsize_r <= !inst_size ? 3'd1 : {inst_size, 1'b0};
    end
    else if(r_cstate == ReadEnd) begin
        araddr_r <= 32'd0;
    end
end

always@(posedge clk) begin
    if(!resetn)
        arvalid_r <= 1'b0;
    else if(r_cstate == ReadStart && r_nstate == Readinst || r_cstate == Read_data_check && r_nstate == Readdata)
        arvalid_r <= 1'b1;
    else if(arready)
        arvalid_r <= 1'b0;
end

//r
always@(posedge clk) begin
    if(!resetn)
        rready_r <= 1'b1;
    else if(r_nstate == Readinst || r_nstate == Read_data_check)
        rready_r <= 1'b1;
    else if(rvalid)
        rready_r <= 1'b0;
end

// WRITE
//aw
always@(posedge clk) begin
    if(!resetn) begin
        awaddr_t   <= 32'd0;
    end else if(data_wt_req && w_cstate == WriteStart) begin
        awaddr_t   <= data_addr;
    end else if(bvalid) begin
        awaddr_t   <= 32'd0;
    end
end

always@(posedge clk) begin
    if(w_cstate == WriteStart && w_nstate == Writeinst) begin
        awaddr_r <= inst_addr;
        awsize_r <= !inst_size ? 3'd1 : {inst_size, 1'b0};
    end else if(w_cstate == WriteStart && w_nstate == Writedata) begin
        awaddr_r <= {data_addr[31:2], 2'd0};
        awsize_r <= data_size_t;
    end
end

always@(posedge clk) begin
    if(!resetn)
        awvalid_r <= 1'b0;
    else if(w_cstate == WriteStart && (w_nstate == Writeinst || w_nstate == Writedata))
        awvalid_r <= 1'b1;
    else if(awready)
        awvalid_r <= 1'b0;
end

//w
always@(posedge clk) begin
    if(w_cstate == WriteStart && w_nstate == Writeinst) begin
        wdata_r <= inst_wdata;
        wstrb_r <= inst_wstrb;
    end
    else if(w_cstate == WriteStart && w_nstate == Writedata) begin
        wdata_r <= data_wdata;
        wstrb_r <= data_wstrb;
    end
end

always@(posedge clk) begin
    if(!resetn) begin
        wvalid_r <= 1'b0;
    end
    else if(w_cstate == WriteStart && (w_nstate == Writeinst || w_nstate == Writedata)) begin
        wvalid_r <= 1'b1;
    end
    else if(wready) begin
        wvalid_r <= 1'b0;
    end
end

//b
always@(posedge clk) begin
    if(!resetn)
        bready_r <= 1'b0;
    else if(w_nstate == Writeinst || w_nstate == Writedata)
        bready_r <= 1'b1;
    else if(bvalid)
        bready_r <= 1'b0;
end

/**** wait ****/
always@(posedge clk) begin
    if(!resetn)
        read_wait_write <= 1'b0;
    else if(r_cstate == ReadStart && r_nstate == Read_data_check && bready && ~bvalid)
        read_wait_write <= 1'b1;
    else if(bvalid)
        read_wait_write <= 1'b0;
end

always@(posedge clk) begin
    if(!resetn)
        write_wait_read <= 1'b0;
    else if(w_cstate == WriteStart && w_nstate == Writedata && rready && ~rvalid)
        write_wait_read <= 1'b1;
    else if(rvalid)
        write_wait_read <= 1'b0;
end


/**** CONVENIENCE ****/
assign arid_eq_i = (arid == 4'd0);
assign arid_eq_d = (arid == 4'd1);

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
