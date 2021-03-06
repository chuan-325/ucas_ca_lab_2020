`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    // to ds
    output [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus  ,
    // flush
    input                          exc_flush,
    //from data-sram
    input  [31                 :0] data_sram_rdata
);

/*  DECLARATION  */

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;

wire [31:0] ms_rt_value;
wire [ 1:0] ms_lad;
wire [ 5:0] ms_ls_type;
wire        ms_mem_re;
wire        ms_gpr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

wire [31:0] ms_badvaddr;

wire ms_flush;
wire es_flush;

wire ms_bd;
wire ms_res_valid;

wire [ 2:0] ms_sel;
wire [ 4:0] ms_rd;
wire [ 3:0] ms_lad_d;

wire mem_res_s_07; // prepare hight bit in byte
wire mem_res_s_15;
wire mem_res_s_23;
wire mem_res_s_31;
wire [31:0] mem_res_lwr; // prepare mem_res selection
wire [31:0] mem_res_lwl;
wire [31:0] mem_res_lhg;
wire [31:0] mem_res_lbg;

wire ms_type_lwr;
wire ms_type_lwl;
wire ms_type_lhu;
wire ms_type_lh;
wire ms_type_lbu;
wire ms_type_lb;
wire ms_type_lw;

wire ms_inst_mtc0;
wire ms_inst_mfc0;
wire ms_inst_eret;
wire ms_exc_sysc;
wire ms_exc_ri;
wire ms_exc_bp;
wire ms_exc_adel_if;
wire ms_exc_adel_ld;
wire ms_exc_ades;
wire ms_exc_of;


/*  LOGIC  */

assign {ms_exc_of      , //162
        ms_badvaddr    , //161:130
        ms_exc_ades    , //129
        ms_exc_adel_ld , //128
        ms_exc_adel_if , //127
        ms_exc_ri      , //126
        ms_exc_bp      , //125
        es_flush       , //124
        ms_bd          , //123
        ms_inst_eret   , //122
        ms_exc_sysc    , //121
        ms_inst_mfc0   , //120
        ms_inst_mtc0   , //119
        ms_sel         , //118:116
        ms_rd          , //115:111
        ms_rt_value    , //110:79
        ms_lad         , //78:77
        ms_ls_type     , //76:71
        ms_mem_re      , //70:70
        ms_gpr_we      , //69:69
        ms_dest        , //68:64
        ms_alu_result  , //63:32
        ms_pc            //31:0
       } = es_to_ms_bus_r;

assign ms_res_valid = ~ms_inst_mfc0;
assign ms_flush     = exc_flush | es_flush;

assign ms_to_ws_bus = {ms_exc_of      , //121
                       ms_badvaddr    , //120:89
                       ms_exc_ades    , //88
                       ms_exc_adel_if , //87
                       ms_exc_adel_ld , //86
                       ms_exc_ri      , //85
                       ms_exc_bp      , //84
                       ms_flush       , //83
                       ms_bd          , //82
                       ms_inst_eret   , //81
                       ms_exc_sysc    , //80
                       ms_inst_mfc0   , //79
                       ms_inst_mtc0   , //78
                       ms_sel         , //77:75
                       ms_rd          , //74:70
                       ms_gpr_we      , //69:69
                       ms_dest        , //68:64
                       ms_final_result, //63:32
                       ms_pc            //31: 0
                      };

assign ms_to_ds_bus = {`MS_TO_DS_BUS_WD{ ms_valid
                                       & ms_gpr_we
                                       }} & {ms_res_valid,    // 37
                                             ms_dest,         // 36:32
                                             ms_final_result  // 31: 0
                                             };

assign ms_ready_go    = 1'b1;
assign ms_allowin     =~ms_valid
                      | ms_ready_go && ws_allowin
                      | exc_flush;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end

/* data_sram */
assign mem_result = {32{ms_type_lwr}} & mem_res_lwr      // LWR
                  | {32{ms_type_lwl}} & mem_res_lwl      // LWL
                  | {32{ms_type_lhg}} & mem_res_lhg      // LH/LHU
                  | {32{ms_type_lbg}} & mem_res_lbg      // LB/LBU
                  | {32{ms_type_lw }} & data_sram_rdata; // LW

assign ms_final_result = ms_inst_mtc0 ? ms_rt_value
                       : ms_mem_re    ? mem_result
                       : ms_alu_result;

/* Generate mem_res */
// lad decoded one-hot
assign ms_lad_d[3] = (ms_lad==2'b11);
assign ms_lad_d[2] = (ms_lad==2'b10);
assign ms_lad_d[1] = (ms_lad==2'b01);
assign ms_lad_d[0] = (ms_lad==2'b00);
// prepare load type
assign ms_type_lwr =  ms_ls_type[4];
assign ms_type_lwl =  ms_ls_type[3];
assign ms_type_lhg =  ms_ls_type[2]; // lh/lhu
assign ms_type_lbg =  ms_ls_type[1]; // lb/lbu
assign ms_type_lw  =  ms_ls_type[0];
// prepare hight bit in byte
assign mem_res_s_07 = ~ms_ls_type[5] & data_sram_rdata[ 7];
assign mem_res_s_15 = ~ms_ls_type[5] & data_sram_rdata[15];
assign mem_res_s_23 = ~ms_ls_type[5] & data_sram_rdata[23];
assign mem_res_s_31 = ~ms_ls_type[5] & data_sram_rdata[31];
// prepare mem_res selection
assign mem_res_lwr = {32{ms_lad_d[0]}} &  data_sram_rdata[31:0]                       // LWR
                   | {32{ms_lad_d[1]}} & {ms_rt_value[31:24], data_sram_rdata[31: 8]}
                   | {32{ms_lad_d[2]}} & {ms_rt_value[31:16], data_sram_rdata[31:16]}
                   | {32{ms_lad_d[3]}} & {ms_rt_value[31: 8], data_sram_rdata[31:24]};
assign mem_res_lwl = {32{ms_lad_d[0]}} & {data_sram_rdata[ 7:0], ms_rt_value[23:0]}   // LWL
                   | {32{ms_lad_d[1]}} & {data_sram_rdata[15:0], ms_rt_value[15:0]}
                   | {32{ms_lad_d[2]}} & {data_sram_rdata[23:0], ms_rt_value[ 7:0]}
                   | {32{ms_lad_d[3]}} &  data_sram_rdata;
assign mem_res_lhg = {32{~ms_lad[1] }} & {{16{mem_res_s_15}}, data_sram_rdata[15: 0]} // LH/LHU
                   | {32{ ms_lad[1] }} & {{16{mem_res_s_31}}, data_sram_rdata[31:16]};
assign mem_res_lbg = {32{ms_lad_d[0]}} & {{24{mem_res_s_07}}, data_sram_rdata[ 7: 0]} // LB/LBU
                   | {32{ms_lad_d[1]}} & {{24{mem_res_s_15}}, data_sram_rdata[15: 8]}
                   | {32{ms_lad_d[2]}} & {{24{mem_res_s_23}}, data_sram_rdata[23:16]}
                   | {32{ms_lad_d[3]}} & {{24{mem_res_s_31}}, data_sram_rdata[31:24]};

endmodule
