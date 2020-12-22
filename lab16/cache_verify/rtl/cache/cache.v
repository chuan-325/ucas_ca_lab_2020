module cache(
    input          clk      ,
    input          resetn   ,
    // cpu_interface
    input          valid    ,
    input          op       ,
    input  [  8:0] index    ,
    input  [ 20:0] tag      ,
    input  [  4:0] offset   ,
    input  [  4:0] wstrb    ,
    input  [ 31:0] wdata    ,
    output         addr_ok  ,
    output         data_ok  ,
    output         rdata    ,
    // axi_interface r
    output         rd_req   ,
    output [  2:0] rd_type  ,
    output [ 31:0] rd_addr  ,
    input          rd_rdy   ,
    input          ret_valid,
    input  [  1:0] ret_last ,
    input  [ 31:0] ret_data ,
    // axi_interface w
    output         wr_req   ,
    output [  2:0] wr_type  ,
    output [ 31:0] wr_addr  ,
    output [  3:0] wr_wstrb ,
    output [128:0] wr_data  ,
    input          wr_rdy  );




endmodule