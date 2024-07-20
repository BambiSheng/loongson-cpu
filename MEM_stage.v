module MEM_stage(
    input  wire        clk,
    input  wire        resetn,
    // exe and mem state interface
    output wire        MEM_allowin,
    input  wire [38:0] EX_rf_bus, // es2ms_bus，{es_res_from_mem, es_rf_we, es_rf_waddr, es_rf_wdata}
    
    input  wire        EX_MEM_valid,
    input  wire [31:0] EX_pc,    
    // mem and wb state interface
    input  wire        WB_allowin,
    output wire [37:0] MEM_rf_bus, // {MEM_rf_we, MEM_rf_waddr, MEM_rf_wdata}
    output wire        MEM_WB_valid,
    output reg  [31:0] MEM_pc,
    // data sram interface
    input  wire [31:0] data_sram_rdata    
);
    wire        MEM_ready_go;
    reg         MEM_valid;
    reg  [31:0] MEM_alu_result ; 
    reg         MEM_res_from_mem;
    reg         MEM_rf_we      ;
    reg  [4 :0] MEM_rf_waddr   ;
    wire [31:0] MEM_rf_wdata   ;
    wire [31:0] MEM_mem_result ;
//------------------------------state control signal---------------------------------------

    assign MEM_ready_go      = 1'b1;
    assign MEM_allowin       = ~MEM_valid | MEM_ready_go & WB_allowin;     
    assign MEM_WB_valid      = MEM_valid & MEM_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            MEM_valid <= 1'b0;
        else
            MEM_valid <= EX_MEM_valid & MEM_allowin; 
    end

//------------------------------EX TO MEM state interface---------------------------------------
    always @(posedge clk) begin
        if(~resetn) begin
            MEM_pc <= 32'b0;
            {MEM_res_from_mem, MEM_rf_we, MEM_rf_waddr, MEM_alu_result} <= 38'b0;
        end
        if(EX_MEM_valid & MEM_allowin) begin
            MEM_pc <= EX_pc;
            {MEM_res_from_mem, MEM_rf_we, MEM_rf_waddr, MEM_alu_result} <= EX_rf_bus;
        end
    end

    assign MEM_mem_result = data_sram_rdata;
    assign MEM_rf_wdata = MEM_res_from_mem ? MEM_mem_result : MEM_alu_result;
    assign MEM_rf_bus  = {MEM_rf_we & MEM_valid, MEM_rf_waddr, MEM_rf_wdata};

endmodule