`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD 34
    `define FS_TO_DS_BUS_WD 64
    `define DS_TO_ES_BUS_WD 152 //144->152
    `define ES_TO_MS_BUS_WD 111 //71->111
    `define MS_TO_WS_BUS_WD 70
    `define WS_TO_RF_BUS_WD 38
    `define ES_TO_DS_BUS_WD 38
    `define MS_TO_DS_BUS_WD 37

    //lab7 newly added
    /*
    `define LW_TYPE 3'b000
    `define LB_TYPE 3'b001
    `define LBU_TYPE 3'b010
    `define LH_TYPE 3'b011
    `define LHU_TYPE 3'b100
    `define LWL_TYPE 3'b101
    `define LWR_TYPE 3'b110

    `define SW_TYPE 3'b000
    `define SB_TYPE 3'b001
    `define SH_TYPE 3'b011
    `define SWL_TYPE 3'b101
    `define SWR_TYPE 3'b110
    */
`endif
