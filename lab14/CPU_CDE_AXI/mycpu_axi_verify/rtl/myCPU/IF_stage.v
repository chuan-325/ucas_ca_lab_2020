`include "mycpu.h"

module if_stage(
    input                          clk              ,
    input                          reset            ,
    //allwoin
    input                          ds_allowin       ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus           ,
    //to ds
    output                         fs_to_ds_valid   ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus     ,
    // from ws
    input  [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus     ,
    // flush
    input  [31:0]                  ws_pc_gen_exc    ,
    input                          exc_flush        ,
    // inst sram interface
    output                         inst_sram_req    ,
    output                         inst_sram_wr     ,
    output [ 1:0]                  inst_sram_size   ,
    output [31:0]                  inst_sram_addr   ,
    output [ 3:0]                  inst_sram_wstrb  ,
    output [31:0]                  inst_sram_wdata  ,
    input                          inst_sram_addr_ok,
    input                          inst_sram_data_ok,
    input  [31:0]                  inst_sram_rdata  ,
    // tlb
    output [18:0]                  s0_vpn2          ,
    output                         s0_odd_page      ,
    input                          s0_found         ,
    input  [19:0]                  s0_pfn           ,
    input                          s0_v
);

/*  DECLARATION  */

wire        ps_to_fs_valid;
wire        ps_ready_go;
wire        ps_allowin;
reg         ps_wait_go_fs;

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;

wire [31:0] seq_pc;
wire [31:0] next_pc;

wire        br_stall;
wire        br_taken;
wire [31:0] br_target;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
wire [31:0] fs_badvaddr;

wire        fs_exc_adel_if;

wire        ds_to_es_valid;
wire        br_taken_t;

wire        fs_addr_ok;

reg         do_req;

reg         fs_addr_ok_r;
reg         fs_first; // first time processed as shkhd
reg         fs_throw;

reg         npc_buf_valid;
reg         inst_buf_valid;
reg         br_buf_valid;

reg [31:0]             npc_buf;
reg [31:0]             inst_buf;
reg [`BR_BUS_WD - 1:0] br_buf;

wire tlb_ex;
wire tlb_invalid;
wire tlb_miss;
wire ws_refetch;
wire es_ex;
wire inst_eret;
wire [31:0] cp0_rdata;
wire fs_ex;
wire [31:0] badvaddr;
wire mapped;
wire [31:0] true_npc_unmapped;
wire [31:0] true_npc;
wire wb_ex;


/*  LOGIC  */

assign ds_to_es_valid = br_bus[34];
assign br_taken_t     = br_taken & br_buf_valid;
assign {br_stall, //33
        br_taken, //32
        br_target //31:0
       } = br_buf[33:0];

assign fs_to_ds_bus = {tlb_invalid   ,  //99
                       tlb_miss      ,  //98
                       fs_ex         ,  //97
                       fs_badvaddr   ,  //96:65
                       fs_exc_adel_if,  //64
                       fs_inst       ,  //63:32
                       fs_pc        };  //31: 0

assign {tlb_ex, //35
        ws_refetch, //34
        wb_ex, //33
        inst_eret, //32
        cp0_rdata //31:0
} = ws_to_fs_bus;

assign tlb_miss    =!s0_found && mapped;
assign tlb_invalid = s0_found && !s0_v && mapped;
assign fs_exc_adel_if = |fs_pc[1:0];
assign fs_ex       = (fs_exc_adel_if|tlb_miss|tlb_invalid) && fs_valid && ~wb_ex;
assign badvaddr    = true_npc_unmapped;
assign true_npc_unmapped = (wb_ex && tlb_ex) ? 32'hbfc00200:
                           (wb_ex &&~tlb_ex) ? 32'hbfc00380:
                            inst_eret        ? cp0_rdata   :
                            ws_refetch       ? cp0_rdata   :
                            npc_buf_valid    ? npc_buf     :
                                               next_pc     ;
assign true_npc    = mapped ? {s0_pfn,{true_npc_unmapped[11:0]}} :
                     true_npc_unmapped;
assign mapped      = (true_npc_unmapped[31:28] < 4'h8 || true_npc_unmapped[31:28] >= 4'hc);
assign s0_vpn2     = true_npc_unmapped[31:13];
assign s0_odd_page = true_npc_unmapped[12];

assign fs_badvaddr = fs_exc_adel_if           ? fs_pc:
                     (tlb_miss | tlb_invalid) ? badvaddr:
                     32'b0;
assign seq_pc      = fs_pc + 3'h4;
assign next_pc     = (wb_ex&&!tlb_ex)? 32'hbfc00380
                   : (wb_ex&& tlb_ex)? 32'hbfc00200
                   : exc_flush       ? ws_pc_gen_exc
                   : br_taken_t      ? br_target
                   : npc_buf_valid   ? npc_buf
                   : seq_pc;

assign fs_addr_ok  = inst_sram_req && inst_sram_addr_ok;


/* pre-IF stage */

assign ps_allowin  = ps_ready_go && fs_allowin;
assign ps_ready_go = fs_addr_ok
                  || ps_wait_go_fs && !(inst_sram_data_ok && inst_buf_valid); // i2 wait for i1, and i1 is going
assign ps_to_fs_valid = !reset && ps_ready_go;


/* inst_sram */

assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'h2;
assign inst_sram_wstrb = 4'h0;
assign inst_sram_wdata = 32'b0;
assign inst_sram_req   = do_req && !br_stall;
assign inst_sram_addr  = (tlb_miss|tlb_invalid) ? 32'hbfc00380
                       : true_npc;
assign fs_inst         = inst_buf_valid ? inst_buf
                                        : inst_sram_rdata;


/* IF stage */

assign fs_ready_go    = ps_ready_go
                      && (inst_buf_valid
                       || inst_sram_data_ok && !fs_throw);
assign fs_allowin     = !fs_valid
                      || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin || exc_flush) begin
        fs_valid <= ps_to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;
    end
    else if ( (fs_allowin || exc_flush)
           && ps_to_fs_valid ) begin
        fs_pc <= next_pc;
    end
end


/* 1-bit control signals */

// do_req
always @(posedge clk) begin
    if (reset) begin
        do_req  <= 1'b0;
    end
    else if (fs_addr_ok) begin
        do_req <= 1'b0;
    end
    else if (fs_first || inst_sram_data_ok && fs_addr_ok_r) begin
        do_req  <= 1'b1;
    end
end

// ps wait go fs
always @(posedge clk) begin
    if (reset) begin
        ps_wait_go_fs <= 1'b0;
    end
    else if (fs_addr_ok && !fs_allowin) begin
        ps_wait_go_fs <= 1'b1;
    end
    else if (fs_allowin || inst_sram_data_ok&&inst_buf_valid) begin
        ps_wait_go_fs <= 1'b0;
    end
end

// fs_addr_ok_r: hands shaked and not recv yet
always @(posedge clk) begin
    if (reset) begin
        fs_addr_ok_r <= 1'b0;
    end
    else if (fs_addr_ok) begin
        fs_addr_ok_r <= 1'b1;
    end
    else if (fs_addr_ok_r
          && inst_sram_data_ok) begin
        fs_addr_ok_r <= 1'b0;
    end
end

// fs_first: high = first request
always @(posedge clk) begin
    if (reset) begin
        fs_first <= 1'b1;
    end
    else if (fs_first && inst_sram_addr_ok) begin //?
        fs_first <= 1'b0;
    end
end

// fs_throw: if current request should be throw
always @(posedge clk) begin
    if (reset) begin
        fs_throw <= 1'b0;
    end
    else if (inst_sram_data_ok) begin
        fs_throw <= 1'b0;
    end
    else if (exc_flush) begin
        fs_throw<= fs_addr_ok_r&&!inst_sram_data_ok;
    end
end




/* data bufs */

// inst_buf
always @(posedge clk) begin
    if (reset || exc_flush) begin
        inst_buf_valid <= 1'b0;
    end
    else if (ds_allowin&&fs_to_ds_valid) begin
        inst_buf_valid <= 1'b0;
    end
    else if ( inst_sram_data_ok&&!fs_throw ) begin
        inst_buf_valid <= 1'b1;
    end

    if (!(ds_allowin&&fs_to_ds_valid) && inst_sram_data_ok&&!fs_throw && !inst_buf_valid) begin
        inst_buf <= inst_sram_rdata;
    end
end

// br_buf
always @(posedge clk) begin
    if (reset || exc_flush) begin
        br_buf_valid <= 1'b0;
    end
    else if (br_taken && ps_ready_go && fs_allowin) begin
        br_buf_valid <= 1'b0;
    end
    else if (ds_to_es_valid) begin
        br_buf_valid <= 1'b1;
    end

    if (reset) begin
        br_buf <= `BR_BUS_WD'b0;
    end else if (ds_to_es_valid
            && !(br_taken && ps_ready_go && fs_allowin)) begin
        br_buf <= br_bus;
    end
end

// npc_buf
always @(posedge clk) begin
    if (reset) begin
        npc_buf_valid <= 1'b0;
    end
    else if (ps_to_fs_valid && fs_allowin) begin
        npc_buf_valid <= 1'b0;
    end
    else if ( exc_flush
           || br_taken && br_buf_valid ) begin
        npc_buf_valid <= 1'b1;
    end

    if (exc_flush) begin
        npc_buf <= ws_pc_gen_exc;
    end
    else if (br_taken && br_buf_valid) begin
        npc_buf <= br_target;
    end
end

endmodule
