module WB_stage(
    input  wire        clk,
    input  wire        resetn,
    // MEM TO WB state interface
    output wire        WB_allowin,
    
    input  wire [38:0] MEM_rf_bus, // {MEM_csr_re,MEM_rf_we, MEM_rf_waddr, MEM_rf_wdata}
    input  wire        MEM_WB_valid,
    input  wire [31:0] MEM_pc,    
     // ID TO WB state interface
    output wire [37:0] WB_rf_bus,  // {WB_rf_we, WB_rf_waddr, WB_rf_wdata}
    
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,

    // WB TO CSR state interface
    input  wire [82:0] MEM_except_bus, // {csr_num, csr_wmask, csr_wvalue, EXC_signal, ERTN_signal, csr_we}

    output wire [13:0] csr_num,
    input  wire [31:0] csr_rvalue,
    output wire  csr_we,
    output wire [31:0] csr_wvalue,
    output wire [31:0] csr_wmask,
    output wire EXC_signal,
    output wire ERTN_signal,
    output reg [31:0] WB_pc,
    output wire [5:0] WB_ecode,
    output wire [8:0] WB_esubcode      
);
    
    wire        WB_ready_go;
    reg         WB_valid;
    wire  [31:0] WB_rf_wdata;
    reg  [31:0] WB_rf_wdata_temp;
    reg  [4 :0] WB_rf_waddr;
    reg         WB_rf_we;

    reg csr_re;
    reg  [81:0] WB_except_bus;
//------------------------------state control signal---------------------------------------

    assign WB_ready_go      = 1'b1;
    assign WB_allowin       = ~WB_valid | WB_ready_go ;     
    always @(posedge clk) begin
        if(~resetn)
            WB_valid <= 1'b0;
        else if(EXC_signal|ERTN_signal)
            WB_valid <= 1'b0;
        else if(WB_allowin)
            WB_valid <= MEM_WB_valid; 
    end

//------------------------------MEM TO WB state interface---------------------------------------
    always @(posedge clk) begin
        if(~resetn) begin
            WB_pc <= 32'b0;
            WB_except_bus <= 82'b0;
            {csr_re,WB_rf_we, WB_rf_waddr, WB_rf_wdata_temp} <= 38'b0;
        end
        if(MEM_WB_valid & WB_allowin) begin
            WB_pc <= MEM_pc;
            WB_except_bus <= MEM_except_bus;
            {csr_re,WB_rf_we, WB_rf_waddr, WB_rf_wdata_temp} <= MEM_rf_bus;
        end
    end

//-----------------------------   WB TO CSR ---------------------------------------
    assign {csr_num, csr_wmask, csr_wvalue, EXC_signal, ERTN_signal, csr_we} = WB_except_bus & {82{WB_valid}}; 
    assign WB_ecode = {6{EXC_signal}} & 6'hb;
    assign WB_esubcode = 9'b0;
//------------------------------  WB TO ID  ---------------------------------------
    assign WB_rf_wdata = csr_re ? csr_rvalue : WB_rf_wdata_temp;
    assign WB_rf_bus = {WB_rf_we & WB_valid, WB_rf_waddr, WB_rf_wdata};

//------------------------------trace debug interface---------------------------------------
    assign debug_wb_pc = WB_pc;
    assign debug_wb_rf_wdata = WB_rf_wdata;
    assign debug_wb_rf_we = {4{WB_rf_we & WB_valid}};
    assign debug_wb_rf_wnum = WB_rf_waddr;
endmodule