module MEM_stage (
    /*
    MEM_stage模块

    clk: 时钟
    resetn: 复位信号
    MEM_allowin: 允许MEM_stage接收数据
    EX_rf_bus: EX_rf总线
    EX_MEM_valid: EX_MEM是否有效
    EX_pc: EX_pc
    EX_mem_ld_inst: EX_mem_ld指令
    WB_allowin: 允许WB_stage接收数据
    MEM_rf_bus: MEM_rf总线
    MEM_WB_valid: MEM_WB是否有效
    MEM_pc: MEM_pc
    data_sram_rdata: 数据存储器读数据
    */

    input  wire        clk,
    input  wire        resetn,
    output wire        MEM_allowin,
    input  wire [39:0] EX_rf_bus,       // {EX_res_from_mem, EX_rf_we, EX_rf_waddr, EX_alu_result}
    input  wire        EX_MEM_valid,
    input  wire [31:0] EX_pc,
    input  wire [ 4:0] EX_mem_ld_inst,  //{inst_ld_w, inst_ld_b, inst_ld_h, inst_ld_bu, inst_ld_hu}
    input  wire        EX_req,          //EX阶段是否需要数据
    input  wire        WB_allowin,
    output wire [38:0] MEM_rf_bus,      // {MEM_csr_re,MEM_rf_we, MEM_rf_waddr, MEM_rf_wdata}
    output wire        MEM_WB_valid,
    output reg  [31:0] MEM_pc,

    input wire WB_EXC_signal,
    output wire MEM_EXC_signal,
    
    output reg [85:0] MEM_except_bus,  // {EX_exc_ALE, ID_exc_ADEF, ID_exc_INE, ID_exc_INT, ID_exc_break, ID_csr_num, ID_csr_wmask, ID_csr_wvalue, ID_exc_syscall, inst_ertn, ID_csr_we}
    input wire  [85:0] EX_except_bus,
    
    output reg  [31:0] MEM_alu_result,

    input wire         data_sram_data_ok,
    input  wire [31:0] data_sram_rdata
);
  wire        MEM_ready_go;
    reg         MEM_valid;
    
    reg         MEM_res_from_mem;
    reg         MEM_rf_we      ;
    reg  [4 :0] MEM_rf_waddr   ;
    wire [31:0] MEM_rf_wdata   ;
    wire [31:0] MEM_mem_result ;
    reg  [7 :0] MEM_mem_ld_inst;
    wire [6 :0] MEM_EXC_signals;

    wire inst_ld_w;
    wire inst_ld_b;
    wire inst_ld_h;
    wire inst_ld_bu;
    wire inst_ld_hu;

    //csr
    reg MEM_csr_re;

    //sram data interface
    wire MEM_wait_data;   //MEM等待数据
    reg  MEM_wait_data_r;
    reg  [31:0] MEM_data_buf;
    reg  MEM_data_buf_valid;

//------------------------------state control signal---------------------------------------

    assign MEM_wait_data  = MEM_wait_data_r & MEM_valid & ~WB_EXC_signal;

    assign MEM_ready_go      = ~MEM_wait_data | MEM_wait_data & data_sram_data_ok;
    assign MEM_allowin       = ~MEM_valid | MEM_ready_go & WB_allowin;     
    assign MEM_WB_valid      = MEM_valid & MEM_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            MEM_valid <= 1'b0;
        else if(WB_EXC_signal)
            MEM_valid <= 1'b0;
        else if(MEM_allowin)
            MEM_valid <= EX_MEM_valid;
            
    end


   assign MEM_EXC_signals= {MEM_except_bus[85:81], MEM_except_bus[2:1]};
   assign MEM_EXC_signal = |MEM_EXC_signals;

//------------------------------data buffer-----------------------------------------------------
always@(posedge clk) begin
    if(~resetn) begin
        MEM_data_buf <= 32'b0;
        MEM_data_buf_valid <= 1'b0;
    end
    else if(MEM_WB_valid & WB_allowin)   // 缓存已经流向下一流水级
        MEM_data_buf_valid <= 1'b0;
    else if(~MEM_data_buf_valid & data_sram_data_ok & MEM_valid) begin
        MEM_data_buf <= data_sram_rdata;
        MEM_data_buf_valid <= 1'b1;
    end
end

//------------------------------EX TO MEM state interface---------------------------------------
    always @(posedge clk) begin
        if(~resetn) begin
            MEM_pc <= 32'b0;
            {MEM_csr_re,MEM_res_from_mem, MEM_rf_we, MEM_rf_waddr, MEM_alu_result} <= 38'b0;
            MEM_mem_ld_inst <= 8'b0;
            MEM_except_bus <= 85'b0;
            MEM_wait_data_r <= 1'b0;
        end
        if(EX_MEM_valid & MEM_allowin) begin
            MEM_pc <= EX_pc;
            {MEM_csr_re,MEM_res_from_mem, MEM_rf_we, MEM_rf_waddr, MEM_alu_result} <= EX_rf_bus;
            MEM_mem_ld_inst <= EX_mem_ld_inst;
            MEM_except_bus <= EX_except_bus;
            MEM_wait_data_r <= EX_req;
        end
    end

    assign {inst_ld_w, inst_ld_b, inst_ld_h, inst_ld_bu, inst_ld_hu} = MEM_mem_ld_inst;

wire [31:0] shift_rdata;
    assign shift_rdata = {24'b0,{32{MEM_data_buf_valid}}& MEM_data_buf|{32{~MEM_data_buf_valid}}&data_sram_rdata}>>{MEM_alu_result[1:0],3'b0 };  //需要修改
    assign MEM_mem_result[7: 0]   =  shift_rdata[7: 0];

    assign MEM_mem_result[15: 8]  =  inst_ld_b ? {8{shift_rdata[7]}} :
                                    inst_ld_bu ? 8'b0 :
                                    shift_rdata[15: 8];

    assign  MEM_mem_result[31:16] = inst_ld_b ? {16{shift_rdata[7]}} :
                                    inst_ld_h ? {16{shift_rdata[15]}} :
                                    inst_ld_bu | inst_ld_hu ? 16'b0 :
                                    shift_rdata[31:16];
    
    assign MEM_rf_wdata = MEM_res_from_mem ?  MEM_mem_result : MEM_alu_result;
    assign MEM_rf_bus  = {MEM_csr_re & MEM_valid,MEM_rf_we & MEM_valid, MEM_rf_waddr, MEM_rf_wdata};

endmodule