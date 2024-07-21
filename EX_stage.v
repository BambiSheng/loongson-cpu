`include "mycpu.h"
module EX_stage (
    /*
  EX_stage模块

  clk: 时钟
  resetn: 复位信号
  EX_allowin: 允许EX_stage接收数据
  ID_EX_valid: ID_EX是否有效
  ID_EX_bus: ID_EX总线
  MEM_allowin: 允许MEM_stage接收数据
  EX_rf_bus: EX_rf总线
  EX_MEM_valid: EX_MEM是否有效
  EX_pc: EX_pc
  EX_mem_ld_inst: EX_mem_ld指令
  data_sram_en: 数据存储器使能
  data_sram_we: 数据存储器写使能
  data_sram_addr: 数据存储器地址
  data_sram_wdata: 数据存储器写数据
  */
    input wire clk,
    input wire resetn,
    output wire EX_allowin,
    input wire ID_EX_valid,
    input wire [`ID_EX_LEN -1:0] ID_EX_bus,
    input wire MEM_allowin,
    output wire [39:0] EX_rf_bus,  // {EX_csr_re,EX_res_from_mem, EX_rf_we, EX_rf_waddr, EX_alu_result}
    output wire EX_MEM_valid,
    output reg [31:0] EX_pc,
    output reg [4:0] EX_mem_ld_inst,  //{inst_ld_w, inst_ld_b, inst_ld_h, inst_ld_bu, inst_ld_hu}

    input wire [81:0] ID_except_bus,
    output reg [81:0] EX_except_bus,
    input wire MEM_EXC_signal,
    input wire WB_EXC_signal,

    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);

  wire         EX_ready_go;
  reg          EX_valid;

  reg  [ 18:0] EX_alu_op;
  reg  [ 31:0] EX_alu_src1;
  reg  [ 31:0] EX_alu_src2;
  wire [ 31:0] EX_alu_result;
  wire         alu_complete;
  reg  [ 31:0] EX_rkd_value;
  reg          EX_res_from_mem;
  wire [  3:0] EX_mem_we;
  reg          EX_rf_we;
  reg  [4 : 0] EX_rf_waddr;

  reg  [  2:0] EX_mem_st_inst;

  wire         inst_st_w;
  wire         inst_st_h;
  wire         inst_st_b;



  reg         EX_csr_re;      //EX阶段csr读使能
  wire        EX_EXC_signal;  //EX阶段异常信号
  
  assign EX_EXC_signal = EX_except_bus[2];
  //流水线状态转移

  assign EX_ready_go  = alu_complete;
  assign EX_allowin   = ~EX_valid | EX_ready_go & MEM_allowin;
  assign EX_MEM_valid = EX_valid & EX_ready_go;
  always @(posedge clk) begin
    if (~resetn) EX_valid <= 1'b0;
    else if(WB_EXC_signal)
      EX_valid <= 1'b0;
    else if (EX_allowin) EX_valid <= ID_EX_valid;
  end

  //------------------------------ID TO EX---------------------------------------
  always @(posedge clk) begin
    if (~resetn)
    begin
      {EX_alu_op, 
      EX_res_from_mem, 
      EX_alu_src1, 
      EX_alu_src2,
      EX_mem_st_inst,
      EX_mem_ld_inst, 
      EX_rf_we, 
      EX_rf_waddr, 
      EX_rkd_value, 
      EX_pc,
      EX_csr_re
      } <= {`ID_EX_LEN{1'b0}};
      EX_except_bus<=82'b0;
    end
    else if (ID_EX_valid & EX_allowin)
    begin
      {EX_alu_op, 
      EX_res_from_mem, 
      EX_alu_src1, 
      EX_alu_src2,
      EX_mem_st_inst,
      EX_mem_ld_inst, 
      EX_rf_we, 
      EX_rf_waddr, 
      EX_rkd_value, 
      EX_pc,
      EX_csr_re
      } <= ID_EX_bus;
      EX_except_bus<=ID_except_bus;
    end
  end
  //alu接口
  alu u_alu (
      .clk       (clk),
      .resetn    (resetn),
      .alu_op    (EX_alu_op),
      .alu_src1  (EX_alu_src1),
      .alu_src2  (EX_alu_src2),
      .alu_result(EX_alu_result),
      .complete  (alu_complete)
  );

  //寄存器数据转发
  assign EX_rf_bus = {EX_csr_re & EX_valid,EX_res_from_mem & EX_valid, EX_rf_we & EX_valid, EX_rf_waddr, EX_alu_result};

  //sram数据接口

  assign {inst_st_w, inst_st_h, inst_st_b} = EX_mem_st_inst;

  wire ex_alu_res_0=EX_alu_result[0];
  wire ex_alu_res_1=EX_alu_result[1];

  wire st_h_low=inst_st_h & ~ex_alu_res_1;
  wire st_h_high=inst_st_h & ex_alu_res_1;

  wire st_b_low=inst_st_b & ~ex_alu_res_0 & ~ex_alu_res_1;
  wire st_b_mid_low=inst_st_b & ex_alu_res_0 & ~ex_alu_res_1;
  wire st_b_mid_high=inst_st_b & ~ex_alu_res_0 & ex_alu_res_1;
  wire st_b_high=inst_st_b & ex_alu_res_0 & ex_alu_res_1;

  assign EX_mem_we[0] = inst_st_w | st_h_low | st_b_low;
  assign EX_mem_we[1] = inst_st_w | st_h_low | st_b_mid_low;
  assign EX_mem_we[2] = inst_st_w | st_h_high | st_b_mid_high;
  assign EX_mem_we[3] = inst_st_w | st_h_high | st_b_high;


  assign data_sram_en = (EX_res_from_mem || EX_mem_we) && EX_valid;
  assign data_sram_we = {4{EX_valid&~EX_EXC_signal&~MEM_EXC_signal&~WB_EXC_signal}} & EX_mem_we;
  assign data_sram_addr = EX_alu_result;

  assign data_sram_wdata[7:0] = EX_rkd_value[7:0];
  assign data_sram_wdata[15:8] = inst_st_b ? EX_rkd_value[7:0] : EX_rkd_value[15:8];
  assign data_sram_wdata[23:16] = inst_st_w ? EX_rkd_value[23:16] : EX_rkd_value[7:0];
  assign data_sram_wdata[31:24] = inst_st_w ? EX_rkd_value[31:24] : 
                                  inst_st_h ? EX_rkd_value[15:8] : EX_rkd_value[7:0] ;

endmodule
