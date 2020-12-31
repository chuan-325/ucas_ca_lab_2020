module cache(
    input          clk      ,
    input          resetn   ,
    // cpu
    input          valid    ,
    input          op       , // 1:write, 0:read
    input  [  7:0] index    , // addr[11:4]
    input  [ 19:0] tag      , // addr[31:12]
    input  [  3:0] offset   , // addr[3:0]
    input  [  3:0] wstrb    ,
    input  [ 31:0] wdata    ,
    output         addr_ok  ,
    output         data_ok  ,
    output [ 31:0] rdata    ,
    // axi r
    output         rd_req   ,
    output [  2:0] rd_type  , // 3'b000:BYTE, 3'b001:HALFWORD, 3'b010:WORD, 3'b100:CacheRow
    output [ 31:0] rd_addr  ,
    input          rd_rdy   ,
    input          ret_valid,
    input  [  1:0] ret_last ,
    input  [ 31:0] ret_data ,
    // axi w
    output         wr_req   ,
    output [  2:0] wr_type  ,
    output [ 31:0] wr_addr  ,
    output [  3:0] wr_wstrb ,
    output [127:0] wr_data  ,
    input          wr_rdy   );

/**********DECLARATION**********/
reg  [ 22:0]  pseudo_random_23;

//Tag Compare
wire         way0_hit;
wire         way1_hit;
wire         cache_hit;

//Data Select
//select data from two ways
wire [127:0]  way0_data;
wire [127:0]  way1_data;
wire [31:0]   way0_load_word;
wire [31:0]   way1_load_word;
wire [31:0]   load_res;
reg           replace_way;
wire [127:0]  replace_data;

//Request Buffer
//save information from input ports
reg           op_r;
reg   [ 7:0]  index_r;
reg   [19:0]  tag_r;
reg   [ 3:0]  offset_r;
reg   [ 3:0]  wstrb_r;
reg   [31:0]  wdata_r;
reg           busy;
reg   [127:0] replace_data_r;

wire         way0_v;
wire         way1_v;
wire [19:0]  way0_tag;
wire [19:0]  way1_tag;

//dirty_ram_0
wire [7:0]   dirty_ram_0_raddr;
wire         dirty_ram_0_rd;
wire         dirty_ram_0_we;
wire [7:0]   dirty_ram_0_waddr;
wire         dirty_ram_0_wd;
//dirty_ram_1
wire [7:0]   dirty_ram_1_raddr;
wire         dirty_ram_1_rd;
wire         dirty_ram_1_we;
wire [7:0]   dirty_ram_1_waddr;
wire         dirty_ram_1_wd;

//BANK
//data_ram_bank0_0
wire [3:0] data_ram_bank0_0_we;
wire [7:0] data_ram_bank0_0_addr;
wire [31:0]data_ram_bank0_0_wdata;
wire [31:0]data_ram_bank0_0_rdata;
//data_ram_bank1_0
wire [3:0] data_ram_bank1_0_we;
wire [7:0] data_ram_bank1_0_addr;
wire [31:0]data_ram_bank1_0_wdata;
wire [31:0]data_ram_bank1_0_rdata;
//data_ram_bank2_0
wire [3:0] data_ram_bank2_0_we;
wire [7:0] data_ram_bank2_0_addr;
wire [31:0]data_ram_bank2_0_wdata;
wire [31:0]data_ram_bank2_0_rdata;
//data_ram_bank3_0
wire [3:0] data_ram_bank3_0_we;
wire [7:0] data_ram_bank3_0_addr;
wire [31:0]data_ram_bank3_0_wdata;
wire [31:0]data_ram_bank3_0_rdata;
//data_ram_bank0_1
wire [3:0] data_ram_bank0_1_we;
wire [7:0] data_ram_bank0_1_addr;
wire [31:0]data_ram_bank0_1_wdata;
wire [31:0]data_ram_bank0_1_rdata;
//data_ram_bank1_1
wire [3:0] data_ram_bank1_1_we;
wire [7:0] data_ram_bank1_1_addr;
wire [31:0]data_ram_bank1_1_wdata;
wire [31:0]data_ram_bank1_1_rdata;
//data_ram_bank2_1
wire [3:0] data_ram_bank2_1_we;
wire [7:0] data_ram_bank2_1_addr;
wire [31:0]data_ram_bank2_1_wdata;
wire [31:0]data_ram_bank2_1_rdata;
//data_ram_bank3_1
wire [3:0] data_ram_bank3_1_we;
wire [7:0] data_ram_bank3_1_addr;
wire [31:0]data_ram_bank3_1_wdata;
wire [31:0]data_ram_bank3_1_rdata;

//main state machine
reg [2:0] cstate;
reg [2:0] nstate;
parameter IDLE    = 3'd0;
parameter LOOKUP  = 3'd1;
parameter MISS    = 3'd2;
parameter REPLACE = 3'd3;
parameter REFILL  = 3'd4;


/**********LOGIC**********/

always@(posedge clk) begin
    if (~resetn) begin
        cstate <= IDLE;
    end
    else begin
        cstate <= nstate;
    end
end

always@(*) begin
    case(cstate)
        IDLE: begin
            if (valid)
                nstate = LOOKUP;
            else
                nstate = cstate;
        end

        LOOKUP:begin
            if (cache_hit)
                nstate = IDLE;
            else
                nstate = MISS;
        end

        MISS:begin
            if (wr_rdy)
                nstate = REPLACE;
            else
                nstate = cstate;
        end

        REPLACE:begin
            if (rd_rdy)
                nstate = REFILL;
            else
                nstate = cstate;
        end

        REFILL:begin
            if (ret_last)
                nstate = IDLE;
            else
                nstate = REFILL;
        end

        default:
            nstate = IDLE;
    endcase
end

/***************CPU & CACHE***************/
reg start;
reg [31:0] rdata_r;
reg [1:0] rd_cnt;
always @(posedge clk) begin
    if (!resetn) begin
        rd_cnt <= 2'b00;
    end
    else if (ret_valid) begin
        rd_cnt <= rd_cnt + 2'b01;
    end
end
always@(posedge clk) begin
    if (!resetn)
        rdata_r <= 0;
    else if (cstate == LOOKUP & cache_hit)
        rdata_r <= load_res;
    else if (offset_r[3:2] == 2'b00 & rd_cnt == 2'b00 & ret_valid)
        rdata_r <= ret_data;
    else if (offset_r[3:2] == 2'b01 & rd_cnt == 2'b01 & ret_valid)
        rdata_r <= ret_data;
    else if (offset_r[3:2] == 2'b10 & rd_cnt == 2'b10 & ret_valid)
        rdata_r <= ret_data;
    else if (offset_r[3:2] == 2'b11 & rd_cnt == 2'b11 & ret_valid)
        rdata_r <= ret_data;
end
always@(posedge clk) begin
    if (!resetn)
        start <= 0;
    else if (valid)
        start <= 1;
    else if (data_ok)
        start <= 0;
end
assign addr_ok = (cstate == LOOKUP);
assign data_ok = (cstate == IDLE & start);
assign rdata = rdata_r;
/***************AXI & CACHE***************/
//r
assign rd_req = (cstate == REPLACE);
assign rd_type = 3'b100;
assign rd_addr = {tag_r,index_r,4'b00};
//w
reg wr_req_r;
wire [19:0]    replace_addr;
reg  [19:0]    replace_addr_r;
assign replace_addr = replace_way? way1_tag : way0_tag;
always@(posedge clk) begin
    if (!resetn)
        wr_req_r <= 0;
    else if (cstate == LOOKUP & nstate == MISS & ((dirty_ram_1_rd == 1)&replace_way | (dirty_ram_0_rd == 1)&~replace_way))
        wr_req_r <= 1;
    else if (wr_rdy)
        wr_req_r <= 0;
end
always@(posedge clk)begin
    if (!resetn) begin
        replace_addr_r <= 0;
    end
    if (cstate == LOOKUP) begin
        replace_addr_r <= replace_addr;
    end
    else if (cstate == REFILL) begin
        replace_addr_r <= 0;
    end
end
always@(posedge clk)begin
    if (!resetn) begin
        replace_data_r <= 0;
    end
    if (cstate == LOOKUP) begin
        replace_data_r <= replace_data;
    end
    else if (cstate == REFILL) begin
        replace_data_r <= 0;
    end
end
assign wr_req = wr_req_r;
assign wr_type = 3'b100;
assign wr_addr = {replace_addr_r,index_r,4'b00};
assign wr_wstrb = 4'b1111;
assign wr_data = replace_data_r;

//Request Buffer
//save information from input ports
always@(posedge clk)begin
    if (!resetn || (busy & data_ok)) begin
        op_r <= 0;
        index_r <= 0;
        tag_r <= 0;
        offset_r <= 0;
        wstrb_r <= 0;
        wdata_r <= 0;
        busy <= 0;
    end
    else if (cstate == IDLE & valid) begin
        op_r <= op;
        index_r <= index;
        tag_r <= tag;
        offset_r <= offset;
        wstrb_r <= wstrb;
        wdata_r <= wdata;
        busy <= 1;
    end
end

//Tag Compare

assign way0_hit = way0_v && (way0_tag == tag_r);
assign way1_hit = way1_v && (way1_tag == tag_r);
//? assign way0_hit = way0_v && (way0_tag == tag_r & cstate != IDLE);
//? assign way1_hit = way1_v && (way1_tag == tag_r & cstate != IDLE);
assign cache_hit = way0_hit || way1_hit;

//Data Select
//select data from two ways
assign way0_data = {data_ram_bank3_0_rdata,data_ram_bank2_0_rdata,data_ram_bank1_0_rdata,data_ram_bank0_0_rdata};
assign way1_data = {data_ram_bank3_1_rdata,data_ram_bank2_1_rdata,data_ram_bank1_1_rdata,data_ram_bank0_1_rdata};
assign way0_load_word = (offset_r[3:2] == 2'd0) ? data_ram_bank0_0_rdata:
                        (offset_r[3:2] == 2'd1) ? data_ram_bank1_0_rdata:
                        (offset_r[3:2] == 2'd2) ? data_ram_bank2_0_rdata:
                                                  data_ram_bank3_0_rdata;
assign way1_load_word = (offset_r[3:2] == 2'd0) ? data_ram_bank0_1_rdata:
                        (offset_r[3:2] == 2'd1) ? data_ram_bank1_1_rdata:
                        (offset_r[3:2] == 2'd2) ? data_ram_bank2_1_rdata:
                                                  data_ram_bank3_1_rdata;
assign load_res = {32{way0_hit}} & way0_load_word
                | {32{way1_hit}} & way1_load_word;
assign replace_data = replace_way ? way1_data : way0_data;
always@(posedge clk) begin
    if (!resetn) begin
        replace_way <= 0;
    end
    else if (cstate == REFILL && ret_last) begin
        replace_way <= pseudo_random_23[0];
    end
end

//LFSR
//generate psudo-random numbers
always @ (posedge clk) begin
    if (!resetn) begin
        pseudo_random_23 <= 23'b100_1010_0101_0010_1000_1010;
    end
    else
        pseudo_random_23 <= {pseudo_random_23[21:0],pseudo_random_23[22] ^ pseudo_random_23[17]};
    end


//TAG_V
//tag_v_ram_0
wire [2:0] tag_v_ram_0_we;
wire [7:0] tag_v_ram_0_addr;
wire [23:0]tag_v_ram_0_wdata;
wire [23:0]tag_v_ram_0_rdata;
assign tag_v_ram_0_we = (cstate == REFILL & replace_way == 0)? 3'b111:0;
assign tag_v_ram_0_addr = busy? index_r : valid? index :0;
assign tag_v_ram_0_wdata = {tag_r,4'b0001};
tag_v_ram tag_v_ram_0(
.clka(clk)                 ,
.wea(tag_v_ram_0_we)       ,
.addra(tag_v_ram_0_addr)   ,
.dina(tag_v_ram_0_wdata)   ,
.douta(tag_v_ram_0_rdata) );

//tag_v_ram_1
wire [2:0] tag_v_ram_1_we;
wire [7:0] tag_v_ram_1_addr;
wire [23:0]tag_v_ram_1_wdata;
wire [23:0]tag_v_ram_1_rdata;
assign tag_v_ram_1_we = (cstate == REFILL & replace_way == 1)? 3'b111:0;
assign tag_v_ram_1_addr = busy? index_r : valid? index :0;
assign tag_v_ram_1_wdata = {tag_r,4'b0001};
tag_v_ram tag_v_ram_1(
.clka(clk)                 ,
.wea(tag_v_ram_1_we)       ,
.addra(tag_v_ram_1_addr)   ,
.dina(tag_v_ram_1_wdata)   ,
.douta(tag_v_ram_1_rdata) );

assign way0_v   = tag_v_ram_0_rdata[0];
assign way1_v   = tag_v_ram_1_rdata[0];
assign way0_tag = tag_v_ram_0_rdata[23:4];
assign way1_tag = tag_v_ram_1_rdata[23:4];

//DIRTY
//dirty_ram_0
assign dirty_ram_0_raddr = busy?index_r: valid? index: 0;
assign dirty_ram_0_waddr = busy?index_r: valid? index: 0;
assign dirty_ram_0_wd = (op_r == 1);
assign dirty_ram_0_we = (cstate == LOOKUP & way0_hit & op_r == 1) | (cstate == REFILL & replace_way == 0 & op_r == 1);
dirty_ram dirty_ram_0(
.clk(clk),
.resetn(resetn),
.raddr(dirty_ram_0_raddr),
.we(dirty_ram_0_we),
.waddr(dirty_ram_0_waddr),
.wdata(dirty_ram_0_wd));

//dirty_ram_1
assign dirty_ram_1_raddr = busy?index_r: valid? index: 0;
assign dirty_ram_1_waddr = busy?index_r: valid? index: 0;
assign dirty_ram_1_wd = (op_r == 1);
assign dirty_ram_1_we = (cstate == LOOKUP & way0_hit & op_r == 1) | (cstate == REFILL & replace_way == 0 & op_r == 1);
dirty_ram dirty_ram_1(
.clk(clk),
.resetn(resetn),
.raddr(dirty_ram_1_raddr),
.we(dirty_ram_1_we),
.waddr(dirty_ram_1_waddr),
.wdata(dirty_ram_1_wd));

//BANK
//data_ram_bank0_0
assign data_ram_bank0_0_we =  (cstate == LOOKUP & cache_hit & way0_hit &offset_r[3:2] == 2'b00 & op_r == 1) ? wstrb_r://hit store
                              (cstate == REFILL & rd_cnt == 2'b00 & ret_valid & replace_way == 0) ? 4'b1111://refill
                              0;
assign data_ram_bank0_0_addr = (cstate == IDLE)?index:index_r;
assign data_ram_bank0_0_wdata = (cstate == LOOKUP & cache_hit & offset_r[3:2] == 2'b00)?wdata_r://hit store
                                (cstate == REFILL)? (offset_r[3:2] == 2'b00)? (wstrb_r == 4'b1111)?wdata_r:
                                                                              (wstrb_r == 4'b1110)?{wdata_r[31:8],ret_data[7:0]}:
                                                                              (wstrb_r == 4'b1100)?{wdata_r[31:16],ret_data[15:0]}:
                                                                              (wstrb_r == 4'b1000)?{wdata_r[31:24],ret_data[23:0]}:
                                                                              (wstrb_r == 4'b0000)?ret_data:
                                                                              (wstrb_r == 4'b0001)?{ret_data[31:24],wdata_r[7:0]}:
                                                                              (wstrb_r == 4'b0011)?{ret_data[31:16],wdata_r[15:0]}:
                                                                              (wstrb_r == 4'b0111)?{ret_data[31:24],wdata_r[23:0]}:
                                                                              wdata_r:
                                                    ret_data:
                                0;
data_ram_bank data_ram_bank0_0(
.clka(clk),
.wea(data_ram_bank0_0_we),
.addra(data_ram_bank0_0_addr),
.dina(data_ram_bank0_0_wdata),
.douta(data_ram_bank0_0_rdata));

//data_ram_bank1_0
assign data_ram_bank1_0_we =  data_ram_bank0_0_we;
assign data_ram_bank1_0_addr = data_ram_bank0_0_addr;
assign data_ram_bank1_0_wdata = data_ram_bank0_0_wdata;
data_ram_bank data_ram_bank1_0(
.clka(clk),
.wea(data_ram_bank1_0_we),
.addra(data_ram_bank1_0_addr),
.dina(data_ram_bank1_0_wdata),
.douta(data_ram_bank1_0_rdata));

//data_ram_bank2_0
assign data_ram_bank2_0_we =  data_ram_bank0_0_we;
assign data_ram_bank2_0_addr = data_ram_bank0_0_addr;
assign data_ram_bank2_0_wdata = data_ram_bank0_0_wdata;
data_ram_bank data_ram_bank2_0(
.clka(clk),
.wea(data_ram_bank2_0_we),
.addra(data_ram_bank2_0_addr),
.dina(data_ram_bank2_0_wdata),
.douta(data_ram_bank2_0_rdata));

//data_ram_bank3_0
assign data_ram_bank3_0_we =  data_ram_bank0_0_we;
assign data_ram_bank3_0_addr = data_ram_bank0_0_addr;
assign data_ram_bank3_0_wdata = data_ram_bank0_0_wdata;
data_ram_bank data_ram_bank3_0(
.clka(clk),
.wea(data_ram_bank3_0_we),
.addra(data_ram_bank3_0_addr),
.dina(data_ram_bank3_0_wdata),
.douta(data_ram_bank3_0_rdata));

//data_ram_bank0_1
assign data_ram_bank0_1_we =  (cstate == LOOKUP & cache_hit & way1_hit &offset_r[3:2] == 2'b00 & op_r == 1) ? wstrb_r://hit store
                              (cstate == REFILL & rd_cnt == 2'b00 & ret_valid & replace_way == 0) ? 4'b1111://refill
                              0;
assign data_ram_bank0_1_addr = (cstate == IDLE)?index:index_r;
assign data_ram_bank0_1_wdata = (cstate == LOOKUP & cache_hit & offset_r[3:2] == 2'b00)?wdata_r://hit store
                                (cstate == REFILL)? (offset_r[3:2] == 2'b00)? (wstrb_r == 4'b1111)?wdata_r:
                                                                              (wstrb_r == 4'b1110)?{wdata_r[31:8],ret_data[7:0]}:
                                                                              (wstrb_r == 4'b1100)?{wdata_r[31:16],ret_data[15:0]}:
                                                                              (wstrb_r == 4'b1000)?{wdata_r[31:24],ret_data[23:0]}:
                                                                              (wstrb_r == 4'b0000)?ret_data:
                                                                              (wstrb_r == 4'b0001)?{ret_data[31:24],wdata_r[7:0]}:
                                                                              (wstrb_r == 4'b0011)?{ret_data[31:16],wdata_r[15:0]}:
                                                                              (wstrb_r == 4'b0111)?{ret_data[31:24],wdata_r[23:0]}:
                                                                              wdata_r:
                                                    ret_data:
                                0;
data_ram_bank data_ram_bank0_1(
.clka(clk),
.wea(data_ram_bank0_1_we),
.addra(data_ram_bank0_1_addr),
.dina(data_ram_bank0_1_wdata),
.douta(data_ram_bank0_1_rdata));

//data_ram_bank1_1
assign data_ram_bank1_1_we =  data_ram_bank0_1_we;
assign data_ram_bank1_1_addr = data_ram_bank0_1_addr;
assign data_ram_bank1_1_wdata = data_ram_bank0_1_wdata;
data_ram_bank data_ram_bank1_1(
.clka(clk),
.wea(data_ram_bank1_1_we),
.addra(data_ram_bank1_1_addr),
.dina(data_ram_bank1_1_wdata),
.douta(data_ram_bank1_1_rdata));

//data_ram_bank2_1
assign data_ram_bank2_1_we =  data_ram_bank0_1_we;
assign data_ram_bank2_1_addr = data_ram_bank0_1_addr;
assign data_ram_bank2_1_wdata = data_ram_bank0_1_wdata;
data_ram_bank data_ram_bank2_1(
.clka(clk),
.wea(data_ram_bank2_1_we),
.addra(data_ram_bank2_1_addr),
.dina(data_ram_bank2_1_wdata),
.douta(data_ram_bank2_1_rdata));

//data_ram_bank3_1
assign data_ram_bank3_1_we =  data_ram_bank0_1_we;
assign data_ram_bank3_1_addr = data_ram_bank0_1_addr;
assign data_ram_bank3_1_wdata = data_ram_bank0_1_wdata;
data_ram_bank data_ram_bank3_1(
.clka(clk),
.wea(data_ram_bank3_1_we),
.addra(data_ram_bank3_1_addr),
.dina(data_ram_bank3_1_wdata),
.douta(data_ram_bank3_1_rdata));


endmodule

