`include "mycpu.h"
module IF_stage (
    /*
  IF_stage模块

  clk: 时钟
  resetn: 复位信号
  ID_allowin: 允许ID_stage接收数据
  br_bus: 分支总线
  IF_ID_valid: IF_ID是否有效
  IF_ID_bus: IF_ID总线
  inst_sram_en: 指令存储器使能
  inst_sram_we: 指令存储器写使能
  inst_sram_addr: 指令存储器地址
  inst_sram_wdata: 指令存储器写数据
  inst_sram_rdata: 指令存储器读数据
  */
    input  wire                   clk,
    input  wire                   resetn,
    // ID to IF interface
    input  wire                   ID_allowin,
    input  wire [           33:0] br_bus,
    // IF to ID interface
    output wire                   IF_ID_valid,
    output wire [`IF_ID_LEN -1:0] IF_ID_bus,

    input wire WB_EXC_signal,
    input wire WB_ERTN_signal,
    input wire [31:0] CSR_2_IF_pc,

    // inst sram interface
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 1:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata
);

  reg         IF_valid;
  wire        IF_ready_go;
  wire        IF_allowin;
  wire        to_IF_valid;

  wire        br_stall;
  wire [31:0] seq_pc;
  wire [31:0] nextpc;

  wire        br_taken;
  wire [31:0] br_target;

  assign {br_stall, br_taken, br_target} = br_bus;

  wire [31:0] IF_inst;
  reg  [31:0] IF_pc;
  wire        IF_ex_ADEF;

   
  wire pre_IF_ready_go;

  reg inst_buffer_valid;
  reg [31:0] inst_buffer;
  reg PC_buf_valid;
  reg [31:0] PC_buffer;


  wire IF_cancel;
  reg inst_discard;

  assign IF_ex_ADEF = (|IF_pc[1:0]) & IF_valid;
  //------------------------------pre-IF signal----------------------------------------------
  assign pre_IF_ready_go = inst_sram_req & inst_sram_addr_ok;
  assign to_IF_valid = pre_IF_ready_go;         
  assign seq_pc = IF_pc + 3'h4;
  assign nextpc = (WB_EXC_signal | WB_ERTN_signal)? CSR_2_IF_pc  : PC_buf_valid? PC_buffer :br_taken? br_target: seq_pc;

  //使用寄存器维护信号
  always @(posedge clk) begin
    if (~resetn) begin
      PC_buf_valid <= 1'b0;
      PC_buffer <= 32'h0;
    end else if (pre_IF_ready_go) begin
      PC_buf_valid <= 1'b0;
      PC_buffer <= 32'h0;
    end else if (WB_EXC_signal) begin
      PC_buffer  <= CSR_2_IF_pc;
      PC_buf_valid <= 1'b1;
    end else if (WB_ERTN_signal) begin
      PC_buffer <= CSR_2_IF_pc;
      PC_buf_valid <= 1'b1;
    end else if (br_taken) begin
      PC_buffer <= br_target;
      PC_buf_valid  <= 1'b1;
    end
  end

  //------------------------------state control signal---------------------------------------
  assign IF_ready_go = (inst_sram_data_ok|inst_buffer_valid) & ~ inst_discard;   //存在有效返回值
  assign IF_allowin = ~IF_valid | IF_ready_go & ID_allowin ;
  assign IF_ID_valid = IF_valid & IF_ready_go;

  always @(posedge clk) begin
    if (~resetn) IF_valid <= 1'b0;
    else if (IF_allowin)  //此时允许进入新的指令
      IF_valid <= to_IF_valid;
    else if (IF_cancel) IF_valid <= 1'b0;
  end
  //------------------------------inst sram interface---------------------------------------

  assign inst_sram_req = IF_allowin & resetn & ~br_stall; // 解决IF_allow置0时多次发送请求导致指令出问题
  assign inst_sram_wr = |inst_sram_wstrb;  //置0即可
  assign inst_sram_wstrb = 4'b0;  // 置0即可
  assign inst_sram_addr = nextpc;
  assign inst_sram_wdata = 32'b0;
  assign inst_sram_size = 3'b0;

  //------------------------------cancel signal----------------------------------------------
  assign IF_cancel = WB_EXC_signal | WB_ERTN_signal | br_taken;
  //丢弃指令部分
  always @(posedge clk) begin
    if (~resetn) inst_discard <= 1'b0;
    else if (!inst_sram_data_ok &&  ~inst_discard && IF_cancel & ~IF_allowin & ~IF_ready_go)  //allowin=0且ready_go=0时
      inst_discard <= 1'b1;
    else if (inst_discard & inst_sram_data_ok)  //需要抹去一条指令
      inst_discard <= 1'b0;
  end
  //------------------------------IF TO ID state interface---------------------------------------
  //IF_pc存前一条指令的pc值
  always @(posedge clk) begin
    if (~resetn) IF_pc <= 32'h1BFF_FFFC;
    else if (IF_allowin & to_IF_valid) IF_pc <= nextpc;
  end

  // 设置寄存器，暂存指令，并用valid信号表示其内指令是否有效
  always @(posedge clk) begin
    if (~resetn) begin
      inst_buffer_valid <= 1'b0;
      inst_buffer <= 32'h0;
    end else if (IF_ID_valid & !ID_allowin ) begin  //
      inst_buffer_valid <= 1'b1;
      inst_buffer <= inst_sram_rdata;
    end
    else if (IF_cancel && inst_buffer_valid && !IF_allowin && IF_ready_go) begin
      inst_buffer_valid <= 1'b0;
    end
    else begin
      inst_buffer_valid <= 1'b0;
      inst_buffer <= 32'h0;
    end
  end

  assign IF_inst   = inst_buffer_valid ? inst_buffer : inst_sram_rdata;
  assign IF_ID_bus = {IF_ex_ADEF, IF_inst, IF_pc};
endmodule
