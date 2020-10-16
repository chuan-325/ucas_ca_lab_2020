`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //from es raw
    input  [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus,
    //from ms raw
    input  [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus
);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire [4:0] es_dest;
wire [4:0] ms_dest;
wire [4:0] ws_dest;
assign es_dest = es_to_ds_bus;
assign ms_dest = ms_to_ds_bus;
assign ws_dest = {5{ws_to_rf_bus[37]}} & ws_to_rf_bus[36:32];

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_stall;
wire        br_taken;
wire [31:0] br_target;

wire [11:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;

wire        dst_is_r31;
wire        dst_is_rt;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;

assign br_bus       = {br_taken,br_target};

assign ds_to_es_bus = {alu_op      ,  //135:124
                       load_op     ,  //123:123
                       src1_is_sa  ,  //122:122
                       src1_is_pc  ,  //121:121
                       src2_is_imm ,  //120:120
                       src2_is_8   ,  //119:119
                       gr_we       ,  //118:118
                       mem_we      ,  //117:117
                       dest        ,  //116:112
                       imm         ,  //111:96
                       rs_value    ,  //95 :64
                       rt_value    ,  //63 :32
                       ds_pc          //31 :0
                      };

// ---Need block? begin---

// if reg/dest == 0 ?
wire rs_neq_0;
wire rt_neq_0;
wire es_dest_neq_0;
wire ms_dest_neq_0;
wire ws_dest_neq_0;
// if(|a=0) neq=0
assign rs_neq_0 = |rs;
assign rt_neq_0 = |rt;
assign es_dest_neq_0 = |es_dest;
assign ms_dest_neq_0 = |ms_dest;
assign ws_dest_neq_0 = |ws_dest;

// if a_rx == b_dest ?
wire rs_eq_es_dest;
wire rt_eq_es_dest;
wire rs_eq_ms_dest;
wire rt_eq_ms_dest;
wire rs_eq_ws_dest;
wire rt_eq_ws_dest;
// if(ab!=0 && a==b) eq=1
assign rs_eq_es_dest = (rs_neq_0 & es_dest_neq_0) && (rs == es_dest); // rs
assign rs_eq_ms_dest = (rs_neq_0 & ms_dest_neq_0) && (rs == ms_dest);
assign rs_eq_ws_dest = (rs_neq_0 & ws_dest_neq_0) && (rs == ws_dest);
assign rt_eq_es_dest = (rt_neq_0 & es_dest_neq_0) && (rt == es_dest); // rt
assign rt_eq_ms_dest = (rt_neq_0 & ms_dest_neq_0) && (rt == ms_dest);
assign rt_eq_ws_dest = (rt_neq_0 & ws_dest_neq_0) && (rt == ws_dest);

// Type define for block situation
// if current type (i.e. at decode stage) has any src from reg
// 19=10+3+4+2
wire type_st;
wire type_rs;
wire type_rt;
wire type_nr;
                            // src from rs & rt
assign type_st = inst_addu  // (op)[rs, rt] -> rd
               | inst_subu  // ...
               | inst_and   // ...
               | inst_nor   // ...
               | inst_or    // ...
               | inst_xor   // ...
               | inst_slt   // ...
               | inst_sltu  // ...
               | inst_beq   // (op)[rs, rt] -> br_taken
               | inst_bne;  // ...
                            // src from rs
assign type_rs = inst_addiu // (op)[rs] -> rt
               | inst_lw    // ...
               | inst_jr;   // j [rs]
                            // src from rt
assign type_rt = inst_sw    // (op)[rt] -> mem
               | inst_sll   // (op)[rt] -> rd
               | inst_sra   // ...
               | inst_srl;  // ...
                            // No src from reg
assign type_nr = inst_lui   // (op)imm -> rt
               | inst_jal;  // (op)PC+8 -> GPR[31]

// if rx == dests?
wire rs_eq_dests;
wire rt_eq_dests;
wire st_eq_dests;
// rs+rt=st
assign rs_eq_dests = rs_eq_es_dest | rs_eq_ms_dest | rs_eq_ws_dest;
assign rt_eq_dests = rt_eq_es_dest | rt_eq_ms_dest | rt_eq_ws_dest;
assign st_eq_dests = rs_eq_dests   | rt_eq_dests   ;

// signal generate
assign ds_ready_go    =  type_st & ~st_eq_dests
                      || type_rs & ~rs_eq_dests
                      || type_rt & ~rt_eq_dests
                      || type_nr ;
// ---Need block? end---

assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid =  ds_valid && ds_ready_go;
always @(posedge clk) begin
//edit1begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
//edit1end
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

assign alu_op[ 0] = inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal;
assign alu_op[ 1] = inst_subu;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_sll;
assign alu_op[ 9] = inst_srl;
assign alu_op[10] = inst_sra;
assign alu_op[11] = inst_lui;

//edit2
assign load_op = res_from_mem;

assign src1_is_sa   = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc   = inst_jal;
assign src2_is_imm  = inst_addiu | inst_lui | inst_lw | inst_sw;
assign src2_is_8    = inst_jal;
assign res_from_mem = inst_lw;
assign dst_is_r31   = inst_jal;
assign dst_is_rt    = inst_addiu | inst_lui | inst_lw;
assign gr_we        = ~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr;
assign mem_we       = inst_sw;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    :
                                   rd    ;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rs_value = rf_rdata1;
assign rt_value = rf_rdata2;

assign rs_eq_rt = (rs_value == rt_value);
assign br_stall = (inst_beq || inst_bne ) & st_eq_dests;
assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  && !rs_eq_rt
                   || inst_jal
                   || inst_jr) && ds_valid;
assign br_target = ( inst_beq
                   | inst_bne) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                    (inst_jr ) ?  rs_value :
                   /*inst_jal*/  {fs_pc[31:28], jidx[25:0], 2'b0};

endmodule
