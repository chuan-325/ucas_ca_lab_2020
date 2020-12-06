`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // flush
    input  [31:0]                  ws_pc_gen_exc  ,
    input                          exc_flush      ,
    // inst sram interface
    output  reg   inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [31:0] inst_sram_addr,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata
);

/*  DECLARATION  */

wire        to_fs_valid;
wire        to_fs_ready_go;

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;

wire [31:0] seq_pc;

wire        br_stall;
wire        br_taken;
wire [31:0] br_target;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
wire [31:0] fs_badvaddr;

wire        fs_exc_adel_if;

wire        ds_to_es_valid;

wire        fs_flush;
reg         exc_flush_r;
reg         rdata_ok_r;

reg         ir_shkhd;
reg         fs_first; // first time processed as shkhd
reg         fs_throw;

reg        br_buf_valid;
reg        npc_buf_valid;
reg        inst_buf_valid;

reg [`BR_BUS_WD - 1:0] br_buf;
reg [31:0]             npc_buf;
reg [31:0]             inst_buf;

/*  LOGIC  */

assign ds_to_es_valid = br_bus[34];
assign {br_stall, //33
        br_taken, //32
        br_target //31:0
       } = br_buf[33:0];

assign fs_to_ds_bus = {fs_badvaddr   ,  //97:66
                       fs_exc_adel_if,  //65
                       fs_flush      ,  //64
                       fs_inst       ,  //63:32
                       fs_pc        };  //31: 0

assign fs_flush       = exc_flush | exc_flush_r;
assign fs_exc_adel_if = |fs_pc[1:0];

assign fs_badvaddr = {32{fs_exc_adel_if}} & fs_pc;
assign seq_pc      = fs_pc + 3'h4;

/* pre-IF stage */

assign to_fs_ready_go = !br_stall
                       &&(inst_sram_req && inst_sram_addr_ok
                        ||ir_shkhd);
assign to_fs_valid = !reset
                  && to_fs_ready_go;// && fs_allowin;

/* inst_sram */

assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'h2;
assign inst_sram_wstrb = 4'h0;
assign inst_sram_wdata = 32'b0;
// req
always @(posedge clk) begin
    if (reset) begin
        inst_sram_req  <= 1'b0;
    end
    else if (inst_sram_req && inst_sram_addr_ok) begin
        inst_sram_req <= 1'b0;
    end
    else if (!inst_sram_req
          && !br_stall
          && (fs_first
            ||inst_sram_data_ok && !fs_throw && to_fs_valid && fs_allowin // earlier
            ||inst_buf_valid && fs_valid && ds_allowin// later
            ||fs_flush && !fs_throw && !ir_shkhd
            )) begin
        inst_sram_req  <= 1'b1;
    end
end
// addr
assign inst_sram_addr = exc_flush     ? ws_pc_gen_exc
                      : (br_taken
                       &~fs_flush)    ? br_target
                      : npc_buf_valid ? npc_buf
                      : seq_pc;
// rdata
always @(posedge clk) begin
    if (reset) begin
        inst_buf_valid <= 1'b0;
    end
    else if (to_fs_valid && fs_allowin) begin
        inst_buf_valid <= 1'b0;
    end
    else if (exc_flush
          && !fs_allowin && fs_ready_go) begin
        inst_buf_valid <= 1'b0;
    end
    else if (!fs_throw && inst_sram_data_ok) begin
        inst_buf_valid <= 1'b1;
    end

    if (reset) begin
        inst_buf <= 32'b0;
    end
    else if (!inst_buf_valid
          && !fs_throw && inst_sram_data_ok) begin
        inst_buf <= inst_sram_rdata;
    end
end

assign fs_inst = (inst_sram_data_ok
                 & ~fs_throw) ? inst_sram_rdata
                              : inst_buf;

/* IF stage */

assign fs_ready_go    = (!br_buf_valid||to_fs_ready_go)
                      && inst_buf_valid;
assign fs_allowin     = !fs_valid
                      || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
// fs_valid, fs_pc
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid & ~exc_flush;
    end
    else if (exc_flush && !fs_allowin) begin
        fs_valid <= 1'b0;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= inst_sram_addr;
    end
end

/* flags */

// fs_first: high = first request
always @(posedge clk) begin
    if (reset) begin
        fs_first <= 1'b1;
    end
    else if (fs_first && inst_sram_addr_ok) begin //?
        fs_first <= 1'b0;
    end
end
// exc_flush_r: store flush until flow
always @(posedge clk) begin
    if (reset) begin
        exc_flush_r <= 1'b0;
    end
    else if (exc_flush) begin
        exc_flush_r <= 1'b1;
    end
    else if (fs_to_ds_valid && ds_allowin) begin
        exc_flush_r <= 1'b0;
    end
end
// ir_shkhd: hands shaked and not recv yet
always @(posedge clk) begin
    if (reset) begin
        ir_shkhd <= 1'b0;
    end
    else if (inst_sram_req && inst_sram_addr_ok) begin
        ir_shkhd <= 1'b1;
    end
    else if (ir_shkhd
          && inst_sram_data_ok) begin
        ir_shkhd <= 1'b0;
    end
end
// fs_throw: if current request should be throw
always @(posedge clk) begin
    if (reset) begin
        fs_throw <= 1'b0;
    end
    else if (exc_flush) begin
        fs_throw<= to_fs_valid
                 |~fs_allowin & ~fs_ready_go;
    end
    else if (fs_throw
           &&(inst_sram_data_ok
           || rdata_ok_r)) begin
        fs_throw <= 1'b0;
    end
end
// rdata_ok_r: store rdata_ok for fs_throw's set
always @(posedge clk) begin
    if (reset) begin
        rdata_ok_r <= 1'b0;
    end
    else if (inst_sram_req) begin
        rdata_ok_r <= 1'b0;
    end
    else if (inst_sram_data_ok) begin
        rdata_ok_r <= 1'b1;
    end
end


/* data bufs */

// br_buf
always @(posedge clk) begin
    if (reset) begin
        br_buf_valid <= 1'b0;
    end
    else if (br_taken && to_fs_ready_go && fs_allowin) begin
        br_buf_valid <= 1'b0;
    end
    else if (ds_to_es_valid) begin
        br_buf_valid <= 1'b1;
    end

    if (reset) begin
        br_buf <= `BR_BUS_WD'b0;
    end else if (ds_to_es_valid
            && !(br_taken && to_fs_ready_go && fs_allowin)) begin
        br_buf <= br_bus;
    end
end

// npc_buf
always @(posedge clk) begin
    if (reset) begin
        npc_buf_valid <= 1'b0;
    end
    else if (to_fs_valid && fs_allowin) begin
    // invalid as an assignment to fs_pc just finished
        npc_buf_valid <= 1'b0;
    end
    else if (!npc_buf_valid) begin
        npc_buf_valid <= 1'b1;
    end

    if (reset) begin
        npc_buf <= 32'hbfc00000;
    end
    else if (exc_flush) begin//!
        npc_buf <= ws_pc_gen_exc;
    end
    else if (!fs_flush
           && br_taken && br_buf_valid) begin
        npc_buf <= br_target;
    end
    else if (!fs_flush) begin
        npc_buf <= seq_pc;
    end
end


endmodule
