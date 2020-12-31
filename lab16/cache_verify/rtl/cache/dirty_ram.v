module dirty_ram(
    input         clk,
    input         resetn,
    //r
    input  [ 7:0] raddr,
    output        rdata,
    //w
    input         we,       //1:enable
    input  [ 7:0] waddr,
    input         wdata);

reg [255:0] rf;
always @(posedge clk) begin
    if (!resetn)
        rf <= 0;
    else if (we)
        rf[waddr]<= wdata;
end

assign rdata = rf[raddr];
endmodule