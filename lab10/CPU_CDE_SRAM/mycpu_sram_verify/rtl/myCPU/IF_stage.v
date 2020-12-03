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

wire        fs_flush;

reg ir_shkhd;
reg flag_first; // first time processed as shkhd
reg flag_throw;

reg [`BR_BUS_WD - 1:0] br_bus_r;

reg [31:0] npc_buf;
reg [31:0] inst_buf;

reg inst_buf_valid;
reg br_bus_r_valid;
reg npc_buf_valid;


/*  LOGIC  */

wire ds_to_es_valid;
assign ds_to_es_valid = br_bus[34];
assign {br_stall, //33
        br_taken, //32
        br_target //31:0
       } = br_bus_r[33:0];

always @(posedge clk) begin
    if (reset) begin
        br_bus_r_valid <= 1'b0;
    end
    else if (br_taken && to_fs_ready_go && fs_allowin) begin
        br_bus_r_valid <= 1'b0;
    end
    else if (ds_to_es_valid) begin
        br_bus_r_valid <= 1'b1;
    end

    if (reset) begin
        br_bus_r <= `BR_BUS_WD'b0;
    end else if (ds_to_es_valid
            && !(br_taken && to_fs_ready_go && fs_allowin)) begin
        br_bus_r <= br_bus;
    end
end

assign fs_to_ds_bus = {fs_badvaddr   ,  //97:66
                       fs_exc_adel_if,  //65
                       fs_flush      ,  //64
                       fs_inst       ,  //63:32
                       fs_pc        };  //31: 0

assign fs_flush = exc_flush;
assign fs_exc_adel_if = |fs_pc[1:0];
assign fs_badvaddr  = {32{fs_exc_adel_if}} & fs_pc;

/* pre-IF stage */

assign to_fs_ready_go = !br_stall
                       &&(inst_sram_req && inst_sram_addr_ok
                        ||ir_shkhd);
assign to_fs_valid = !reset
                  && to_fs_ready_go && fs_allowin;


assign seq_pc = fs_pc + 3'h4;

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
    else if (fs_flush) begin
        npc_buf <= ws_pc_gen_exc;
    end
    else if (br_taken && br_bus_r_valid) begin
        npc_buf <= br_target;
    end
    else begin
        npc_buf <= seq_pc;
    end
end

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
          && (flag_first
            ||inst_sram_data_ok && to_fs_valid && fs_allowin
            ||inst_buf_valid && fs_valid && ds_allowin)) begin //?
        inst_sram_req  <= 1'b1;
    end
end
// addr
assign inst_sram_addr = fs_flush      ? ws_pc_gen_exc
                      : br_taken      ? br_target
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
    else if (inst_sram_data_ok) begin
        inst_buf_valid <= !flag_throw;
    end

    if (reset) begin
        inst_buf <= 32'b0;
    end
    else if (!inst_buf_valid && inst_sram_data_ok) begin
        inst_buf <= inst_sram_rdata;
    end
end


assign fs_inst = inst_sram_data_ok ? inst_sram_rdata
                                   : inst_buf;

/* IF stage */

assign fs_ready_go    = (!br_bus_r_valid||to_fs_ready_go)
                      && inst_buf_valid;
assign fs_allowin     = !fs_valid
                      || fs_ready_go && ds_allowin
                      || fs_flush;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
// fs_valid, fs_pc
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_flush) begin
        fs_valid <= !flag_throw;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= inst_sram_addr;
    end
end

// lab10
// flag_first: high = first request
always @(posedge clk) begin
    if (reset) begin
        flag_first <= 1'b1;
    end
    else if (flag_first && inst_sram_addr_ok) begin //?
        flag_first <= 1'b0;
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
// flag_throw: need to throw current rdata for last flush
always @(posedge clk) begin
    if (reset) begin
        flag_throw <= 1'b0;
    end else if (fs_flush
             && (fs_allowin && to_fs_valid
              ||!fs_allowin &&!fs_ready_go)) begin
        flag_throw <= 1'b1;
    end else if (flag_throw && inst_sram_data_ok) begin
        flag_throw <= 1'b0;
    end
end

endmodule
