`include "mycpu.h"

module exe_stage(
    input                          clk            ,
    input                          reset          ,
    //allowin
    input                          ms_allowin     ,
    output                         es_allowin     ,
    //from ds
    input                          ds_to_es_valid ,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus   ,
    //to ms
    output                         es_to_ms_valid ,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus   ,
    // to ds
    output [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus   ,
    // flush
    input                          exc_flush      ,
    // data sram interface
    output                         data_sram_en   ,
    output [ 3:0]                  data_sram_wen  ,
    output [31:0]                  data_sram_addr ,
    output [31:0]                  data_sram_wdata
);

/* ------------------------------ DECLARATION ------------------------------ */

reg  es_valid;
wire es_ready_go;

wire es_hilo_we;

// register: HI, LO
reg [31:0] hi;
reg [31:0] lo;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

wire es_inst_mtc0;
wire es_inst_mfc0;
wire es_exc_sysc ;
wire es_inst_eret;
wire es_inst_mtlo;
wire es_inst_mthi;
wire es_inst_mflo;
wire es_inst_mfhi;
wire es_op_divu  ;
wire es_op_div   ;
wire es_op_multu ;
wire es_op_mult  ;
//lab9
wire es_exc_bp  ;
wire es_exc_ri ;
//lab9
wire es_of_valid ;
wire es_exc_of   ;

wire es_exc_adel_if;
wire es_exc_adel_ld;
wire es_exc_ades   ;

wire [11:0] es_alu_op     ;
wire        es_mem_re     ;
wire        es_src1_is_sa ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm;
wire        es_src2_is_8  ;
wire        es_gpr_we     ;
wire        es_mem_we     ;
wire        es_mem_we_r   ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;

wire [31:0] ds_badvaddr;
wire [31:0] es_badvaddr;

wire es_flush;
wire ds_flush;
wire es_ignore;
wire es_ex;
wire es_bd;
wire es_res_valid;
wire es_div_ready;
reg  es_pre_flush;

wire [31:0] es_alu_src1  ;
wire [31:0] es_alu_src2  ;
wire [31:0] es_alu_result;
wire [31:0] es_res_r     ;
wire [31:0] es_hi_res    ;
wire [31:0] es_lo_res    ;
wire        es_alu_of    ;

wire es_src2_is_uimm;
wire [31:0] es_alu_src2_imm;

wire [32:0] es_mult_a;
wire [32:0] es_mult_b;
wire [65:0] es_mult_result;
wire [31:0] es_dividend;
wire [31:0] es_divisor;

wire [63:0] es_div_dout;
reg es_div_end_valid;
wire es_div_end_ready;
reg es_div_sor_valid;
wire es_div_sor_ready;
wire es_div_out_valid;
reg es_div_in_flag;
wire es_div_in_ready;

wire [63:0] es_divu_dout;
reg es_divu_end_valid;
wire es_divu_end_ready;
reg es_divu_sor_valid;
wire es_divu_sor_ready;
wire es_divu_out_valid;
reg es_divu_in_flag;
wire es_divu_in_ready;

wire [3:0] write_strb_swr;
wire [3:0] write_strb_swl;
wire [3:0] write_strb_sh;
wire [3:0] write_strb_sb;

wire [31:0] write_data_swr;
wire [31:0] write_data_swl;
wire [31:0] write_data_sh;
wire [31:0] write_data_sb;

wire [ 3:0] write_strb;
wire [31:0] write_data;

wire [2:0] es_sel;
wire [4:0] es_rd;

wire [5:0] es_ls_type   ;
wire [1:0] es_ls_laddr  ;
wire [3:0] es_ls_laddr_d;

/* ------------------------------ LOGIC ------------------------------ */

assign {es_of_valid    ,  //199 lab9 b
        ds_badvaddr    ,  //198:167
        es_exc_adel_if ,  //166
        es_exc_ri      ,  //165
        es_exc_bp      ,  //164
        ds_flush       ,  //163
        es_bd          ,  //162
        es_inst_eret   ,  //161
        es_exc_sysc    ,  //160
        es_inst_mfc0   ,  //159
        es_inst_mtc0   ,  //158
        es_sel         ,  //157:155
        es_rd          ,  //154:150
        es_ls_type     ,  //149:144
        es_inst_mtlo   ,  //143
        es_inst_mthi   ,  //142
        es_inst_mflo   ,  //141
        es_inst_mfhi   ,  //140
        es_op_divu     ,  //139
        es_op_div      ,  //138
        es_op_multu    ,  //137
        es_op_mult     ,  //136
        es_alu_op      ,  //135:124
        es_mem_re      ,  //123:123
        es_src1_is_sa  ,  //122:122
        es_src1_is_pc  ,  //121:121
        es_src2_is_imm ,  //120:120
        es_src2_is_8   ,  //119:119
        es_gpr_we      ,  //118:118
        es_mem_we      ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;
assign es_mem_we_r    = es_mem_we & ~es_ignore;
assign es_exc_adel_ld = es_ls_type[2] & es_gpr_we &  data_sram_addr[0]   // load halfword
                      | es_ls_type[0] & es_gpr_we & |data_sram_addr[1:0];// load word
assign es_exc_ades    = es_ls_type[2] & es_mem_we &  data_sram_addr[0]   // store halfword
                      | es_ls_type[0] & es_mem_we & |data_sram_addr[1:0];// store word
/* note for ades:
 * ades use 'mem_we' instead of 'mem_we_r'
 * because ades is meaningless for to-be-flushed inst
 */

// ls_laddr decoded one-hot
assign es_ls_laddr      =  es_alu_result[1:0];
assign es_ls_laddr_d[3] = (es_ls_laddr==2'b11);
assign es_ls_laddr_d[2] = (es_ls_laddr==2'b10);
assign es_ls_laddr_d[1] = (es_ls_laddr==2'b01);
assign es_ls_laddr_d[0] = (es_ls_laddr==2'b00);

assign es_flush = exc_flush | ds_flush;
assign es_ex    = es_inst_eret
                | es_exc_adel_if
                | es_exc_ri
                | es_exc_of
                | es_exc_bp
                | es_exc_sysc
                | es_exc_adel_ld
                | es_exc_ades;

assign es_to_ms_bus = {es_exc_of     , //162
                       es_badvaddr   , //161:130
                       es_exc_ades   , //129
                       es_exc_adel_ld, //128
                       es_exc_adel_if, //127
                       es_exc_ri     , //126
                       es_exc_bp     , //125
                       es_flush      , //124
                       es_bd         , //123
                       es_inst_eret  , //122
                       es_exc_sysc   , //121
                       es_inst_mfc0  , //120
                       es_inst_mtc0  , //119
                       es_sel        , //118:116
                       es_rd         , //115:111
                       es_rt_value   , //110:79
                       es_ls_laddr   , //78:77
                       es_ls_type    , //76:71
                       es_mem_re     , //70:70
                       es_gpr_we     , //69:69
                       es_dest       , //68:64
                       es_res_r      , //63:32 originally es_alu_result
                       es_pc          //31:0
                      };

assign es_res_valid = ~es_mem_re
                    & ~es_inst_mfc0;

assign es_to_ds_bus = {`ES_TO_DS_BUS_WD{ es_valid
                                       & es_gpr_we
                                       }} & {es_res_valid, //37    es_res_valid
                                             es_dest,      //36:32 es_dest
                                             es_res_r      //31: 0 es_res_r
                                             };
// es_ready_go change from 1'b1
assign es_div_ready   =~(es_op_div
                        |es_op_divu) | es_hilo_we;
assign es_ready_go    = es_div_ready | es_flush;
assign es_allowin     = !es_valid
                      || es_ready_go && ms_allowin
                      || es_flush;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

// pre-flush
always @(posedge clk) begin
    if (reset) begin
        es_pre_flush <= 1'b0;
    end
    else if (es_ex & es_valid & ~es_flush ) begin
        es_pre_flush <= 1'b1;
    end
    else if (es_flush) begin
        es_pre_flush <= 1'b0;
    end
end

// es_alu_src2: imm
assign es_src2_is_uimm = es_src2_is_imm & (es_alu_op[4] // andi
                                          |es_alu_op[6] // ori
                                          |es_alu_op[7] // xori
                                          );
assign es_alu_src2_imm[15: 0] = es_imm[15:0];
assign es_alu_src2_imm[31:16] = {16{~es_src2_is_uimm // not uimm: imm[15]
                                   & es_imm[15]}};   //     uimm: 0

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} :
                     es_src1_is_pc  ? es_pc[31:0]           :
                                      es_rs_value           ;
assign es_alu_src2 = es_src2_is_imm ? es_alu_src2_imm       :
                     es_src2_is_8   ? 32'd8                 :
                                      es_rt_value           ;


/* 33-bit multiplier: begin */
assign es_mult_a      = {es_op_mult & es_alu_src1[31], es_alu_src1};
assign es_mult_b      = {es_op_mult & es_alu_src2[31], es_alu_src2};
assign es_mult_result = $signed(es_mult_a) * $signed(es_mult_b)    ;
/* 33-bit multiplier: end */


/* 32-bit dividers (my_div, my_divu): begin */
// Gerneral input
assign es_dividend = {32{es_op_div|es_op_divu}} & es_alu_src1;
assign es_divisor  = {32{es_op_div|es_op_divu}} & es_alu_src2;
/* div begin */
// div input sending valid
assign es_div_in_ready = es_div_end_ready & es_div_sor_ready;
always @(posedge clk ) begin
    if (reset) begin                                   // reset
        es_div_end_valid <= 1'b0;
        es_div_sor_valid <= 1'b0;
        es_div_in_flag   <= 1'b0;
    end
    else if (~es_div_in_flag & es_op_div) begin       // valid: require ready
        es_div_end_valid <= 1'b1;
        es_div_sor_valid <= 1'b1;
        es_div_in_flag   <= 1'b1;
    end
    else if (es_div_in_flag & es_div_in_ready) begin  // ready & flag
        es_div_end_valid <= 1'b0;
        es_div_sor_valid <= 1'b0;
    end
    else if (es_div_in_flag & es_div_out_valid) begin // flag set to 1'b0
        es_div_in_flag   <= 1'b0;
    end
end
/* div end */
/* divu begin */
// divu input sending valid
assign es_divu_in_ready = es_divu_end_ready & es_divu_sor_ready;
always @(posedge clk ) begin
    if (reset) begin                                     // reset
        es_divu_end_valid <= 1'b0;
        es_divu_sor_valid <= 1'b0;
        es_divu_in_flag   <= 1'b0;
    end
    else if (~es_divu_in_flag & es_op_divu) begin       // valid: require ready
        es_divu_end_valid <= 1'b1;
        es_divu_sor_valid <= 1'b1;
        es_divu_in_flag   <= 1'b1;
    end
    else if (es_divu_in_flag & es_divu_in_ready) begin  // ready & flag
        es_divu_end_valid <= 1'b0;
        es_divu_sor_valid <= 1'b0;
    end
    else if (es_divu_in_flag & es_divu_out_valid) begin // flag set to 1'b0
        es_divu_in_flag  <= 1'b0;
    end
end
/* divu end */
/* 32-bit dividers (my_div, my_divu): end */


/* HI, LO R&W: begin */
assign es_hilo_we   = es_op_mult
                    | es_op_multu
                    | es_op_div  &  es_div_out_valid
                    | es_op_divu &  es_divu_out_valid;
assign es_ignore = es_flush | es_pre_flush | es_ex;

assign es_hi_res    = {32{es_op_mult|es_op_multu}} & es_mult_result[63:32]
                    | {32{es_op_div             }} & es_div_dout[31:0]
                    | {32{es_op_divu            }} & es_divu_dout[31:0];
assign es_lo_res    = {32{es_op_mult|es_op_multu}} & es_mult_result[31:0]
                    | {32{es_op_div             }} & es_div_dout[63:32]
                    | {32{es_op_divu            }} & es_divu_dout[63:32];

always @(posedge clk) begin
    if (reset) begin
        hi <= 32'b0;
        lo <= 32'b0;
    end
    else if (es_hilo_we & es_valid & ~es_ignore) begin // mult/div
        hi <= es_hi_res;
        lo <= es_lo_res;
    end
    else if (es_inst_mthi & es_valid & ~es_ignore) begin // mthi
        hi <= es_rs_value;
    end
    else if (es_inst_mtlo & es_valid & ~es_ignore) begin // mtlo
        lo <= es_rs_value;
    end
end
/* HI, LO R&W: end */


/* instantiated: begin */
my_div inst_my_div(
    // clk
    .aclk                   (clk),             //in
    // dividend
    .s_axis_dividend_tdata (es_dividend),      //in
    .s_axis_dividend_tvalid(es_div_end_valid), //in
    .s_axis_dividend_tready(es_div_end_ready), //out
    // divisor
    .s_axis_divisor_tdata  (es_divisor),       //in
    .s_axis_divisor_tvalid (es_div_sor_valid), //in
    .s_axis_divisor_tready (es_div_sor_ready), //out
    // res
    .m_axis_dout_tdata     (es_div_dout),      //out
    .m_axis_dout_tvalid    (es_div_out_valid)  //out
);
my_divu inst_my_divu(
    // clk
    .aclk                   (clk),             //in
    // dividend
    .s_axis_dividend_tdata (es_dividend),      //in
    .s_axis_dividend_tvalid(es_divu_end_valid), //in
    .s_axis_dividend_tready(es_divu_end_ready), //out
    // divisor
    .s_axis_divisor_tdata  (es_divisor),       //in
    .s_axis_divisor_tvalid (es_divu_sor_valid), //in
    .s_axis_divisor_tready (es_divu_sor_ready), //out
    // res
    .m_axis_dout_tdata     (es_divu_dout),      //out
    .m_axis_dout_tvalid    (es_divu_out_valid)  //out
);

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .alu_of     (es_alu_of    )
    );
/* instantiated: end */

assign es_res_r  = {32{  es_inst_mfhi}}  & hi
                 | {32{  es_inst_mflo}}  & lo
                 | {32{~(es_inst_mfhi
                        |es_inst_mflo)}} & es_alu_result ;
assign es_exc_of = es_of_valid & es_alu_of;

/*  Generate write_strb & write data: begin */
// prepare write_strb selection
assign write_strb_swr = {4{ es_ls_laddr_d[0]}} & 4'b1111 // SWR
                      | {4{ es_ls_laddr_d[1]}} & 4'b1110
                      | {4{ es_ls_laddr_d[2]}} & 4'b1100
                      | {4{ es_ls_laddr_d[3]}} & 4'b1000;
assign write_strb_swl = {4{ es_ls_laddr_d[0]}} & 4'b0001 // SWL
                      | {4{ es_ls_laddr_d[1]}} & 4'b0011
                      | {4{ es_ls_laddr_d[2]}} & 4'b0111
                      | {4{ es_ls_laddr_d[3]}} & 4'b1111;
assign write_strb_sh  = {4{~es_ls_laddr[1]  }} & 4'b0011 // SH
                      | {4{ es_ls_laddr[1]  }} & 4'b1100;
assign write_strb_sb  = {4{ es_ls_laddr_d[0]}} & 4'b0001 // SB
                      | {4{ es_ls_laddr_d[1]}} & 4'b0010
                      | {4{ es_ls_laddr_d[2]}} & 4'b0100
                      | {4{ es_ls_laddr_d[3]}} & 4'b1000;
// prepare write_data selection
assign write_data_swr = {32{es_ls_laddr_d[0]}} &  es_rt_value                // SWR
                      | {32{es_ls_laddr_d[1]}} & {es_rt_value[23:0],  8'b0}
                      | {32{es_ls_laddr_d[2]}} & {es_rt_value[15:0], 16'b0}
                      | {32{es_ls_laddr_d[3]}} & {es_rt_value[ 7:0], 24'b0};
assign write_data_swl = {32{es_ls_laddr_d[0]}} & {24'b0, es_rt_value[31:24]} // SWL
                      | {32{es_ls_laddr_d[1]}} & {16'b0, es_rt_value[31:16]}
                      | {32{es_ls_laddr_d[2]}} & { 8'b0, es_rt_value[31: 8]}
                      | {32{es_ls_laddr_d[3]}} &  es_rt_value;
assign write_data_sh = {2{es_rt_value[15:0]}};                               // SH
assign write_data_sb = {4{es_rt_value[ 7:0]}};                               // SB
// Generate correct write_strb & write_data
assign write_strb = {4{ es_ls_type[4]}} & write_strb_swr // SWR
                  | {4{ es_ls_type[3]}} & write_strb_swl // SWL
                  | {4{ es_ls_type[2]}} & write_strb_sh  // SH
                  | {4{ es_ls_type[1]}} & write_strb_sb  // SB
                  | {4{ es_ls_type[0]}} & 4'b1111;       // SW
assign write_data = {32{es_ls_type[4]}} & write_data_swr // SWR
                  | {32{es_ls_type[3]}} & write_data_swl // SWL
                  | {32{es_ls_type[2]}} & write_data_sh  // SH
                  | {32{es_ls_type[1]}} & write_data_sb  // SB
                  | {32{es_ls_type[0]}} & es_rt_value;   // SW
/* Generate write_strb & write data: end */

assign es_badvaddr = es_exc_adel_if ? ds_badvaddr : data_sram_addr; // if:ld/st

assign data_sram_en    = ~es_ignore;
assign data_sram_wen   = es_mem_we_r & es_valid & ~es_ignore ? write_strb : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = write_data;

endmodule
