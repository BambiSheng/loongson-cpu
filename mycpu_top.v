`include "mycpu.h"
module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    wire        ID_allowin;
    wire        EX_allowin;
    wire        MEM_allowin;
    wire        WB_allowin;

    wire        IF_ID_valid;
    wire        ID_EX_valid;
    wire        EX_MEM_valid;
    wire        MEM_WB_valid;

    wire [31:0] EX_pc;
    wire [31:0] MEM_pc;

    wire [38:0] EX_rf_bus;
    wire [37:0] MEM_rf_bus;
    wire [37:0] WB_rf_bus;

    wire [32:0] br_bus;

    wire [`IF_ID_LEN -1:0] IF_ID_bus;
    wire [`ID_EX_LEN -1:0] ID_EX_bus;

    wire [4:0] EX_mem_ld_inst;


    IF_stage IF(
        .clk(clk),
        .resetn(resetn),

        .ID_allowin(ID_allowin),
        .br_bus(br_bus),
        .IF_ID_valid(IF_ID_valid),
        .IF_ID_bus(IF_ID_bus),

        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata)
    );

    ID_stage ID(
        .clk(clk),
        .resetn(resetn),

        .IF_ID_valid(IF_ID_valid),
        .ID_allowin(ID_allowin),
        .br_bus(br_bus),
        .IF_ID_bus(IF_ID_bus),

        .EX_allowin(EX_allowin),
        .ID_EX_valid(ID_EX_valid),
        .ID_EX_bus(ID_EX_bus),

        .WB_rf_bus(WB_rf_bus),
        .MEM_rf_bus(MEM_rf_bus),
        .EX_rf_bus(EX_rf_bus)
    );

    EX_stage EX(
        .clk(clk),
        .resetn(resetn),
        
        .EX_allowin(EX_allowin),
        .ID_EX_valid(ID_EX_valid),
        .ID_EX_bus(ID_EX_bus),

        .MEM_allowin(MEM_allowin),
        .EX_rf_bus(EX_rf_bus),
        .EX_MEM_valid(EX_MEM_valid),
        .EX_pc(EX_pc),
        .EX_mem_ld_inst(EX_mem_ld_inst),
        
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata)
    );

    MEM_stage MEM(
        .clk(clk),
        .resetn(resetn),

        .MEM_allowin(MEM_allowin),
        .EX_rf_bus(EX_rf_bus),
        .EX_MEM_valid(EX_MEM_valid),
        .EX_pc(EX_pc),
        .EX_mem_ld_inst(EX_mem_ld_inst),

        .WB_allowin(WB_allowin),
        .MEM_rf_bus(MEM_rf_bus),
        .MEM_WB_valid(MEM_WB_valid),
        .MEM_pc(MEM_pc),

        .data_sram_rdata(data_sram_rdata)
    ) ;

    WB_stage WB(
        .clk(clk),
        .resetn(resetn),

        .WB_allowin(WB_allowin),
        .MEM_rf_bus(MEM_rf_bus),
        .MEM_WB_valid(MEM_WB_valid),
        .MEM_pc(MEM_pc),

        .WB_rf_bus(WB_rf_bus),

        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
endmodule
