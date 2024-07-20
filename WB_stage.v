module WB_stage(
    input  wire        clk,
    input  wire        resetn,
    // mem and ws state interface
    output wire        WB_allowin,
    input  wire [37:0] MEM_rf_bus, // {MEM_rf_we, MEM_rf_waddr, MEM_rf_wdata}
    input  wire        MEM_WB_valid,
    input  wire [31:0] MEM_pc,    
     // id and ws state interface
    output wire [37:0] WB_rf_bus,  // {WB_rf_we, WB_rf_waddr, WB_rf_wdata}
    
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
   
);
    
    wire        WB_ready_go;
    reg         WB_valid;
    reg  [31:0] WB_pc;
    reg  [31:0] WB_rf_wdata;
    reg  [4 :0] WB_rf_waddr;
    reg         WB_rf_we;
//------------------------------state control signal---------------------------------------

    assign WB_ready_go      = 1'b1;
    assign WB_allowin       = ~WB_valid | WB_ready_go ;     
    always @(posedge clk) begin
        if(~resetn)
            WB_valid <= 1'b0;
        else if(WB_allowin)
            WB_valid <= MEM_WB_valid; 
    end

//------------------------------MEM TO WB state interface---------------------------------------
    always @(posedge clk) begin
        if(~resetn) begin
            WB_pc <= 32'b0;
            {WB_rf_we, WB_rf_waddr, WB_rf_wdata} <= 38'b0;
        end
        if(MEM_WB_valid & WB_allowin) begin
            WB_pc <= MEM_pc;
            {WB_rf_we, WB_rf_waddr, WB_rf_wdata} <= MEM_rf_bus;
        end
    end

//------------------------------id and ws state interface---------------------------------------

    assign WB_rf_bus = {WB_rf_we & WB_valid, WB_rf_waddr, WB_rf_wdata};

//------------------------------trace debug interface---------------------------------------
    assign debug_wb_pc = WB_pc;
    assign debug_wb_rf_wdata = WB_rf_wdata;
    assign debug_wb_rf_we = {4{WB_rf_we & WB_valid}};
    assign debug_wb_rf_wnum = WB_rf_waddr;
endmodule