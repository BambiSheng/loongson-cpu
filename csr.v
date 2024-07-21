`include "mycpu.h"
module csr(
    /*
    csr模块

    clk: 时钟
    resetn: 复位信号(取反)
    csr_num: csr编号
    rdata: 读取数据

    we: 写使能
    wdata: 写数据
    wmask: 写掩码

    EXC_signal: 异常信号
    ERTN_signal: 异常返回信号
    EXC_ecode: 异常代码
    EXC_esubcode: 异常子代码
    EXC_pc: 异常地址
    CSR_2_IF_pc: csr到IF_stage的pc
    */
    input  wire        clk,
    input  wire        resetn,

    input  wire [13:0] csr_num,
    output wire [31:0] rdata,

    input  wire        we,
    input  wire [31:0] wdata,
    input wire [31:0] wmask,


    input wire EXC_signal,
    input wire ERTN_signal,
    input wire [5:0] EXC_ecode,
    input wire [8:0] EXC_esubcode,
    input wire [31:0] EXC_pc,
    output wire [31:0] CSR_2_IF_pc
  );

  //-------------------------csr寄存器-------------------------------
  // CRMD
  wire [31:0] crmd;
  reg [1:0] crmd_PLV;
  reg crmd_IE;
  reg crmd_DA;
  reg crmd_PG;
  reg [1:0] crmd_DATF;
  reg [1:0] crmd_DATM;
  assign crmd = {23'b0, crmd_DATM, crmd_DATF, crmd_PG, crmd_DA, crmd_IE, crmd_PLV};


  // PRMD
  wire [31:0] prmd;
  reg [1:0] prmd_PPLV;
  reg prmd_PIE;
  assign prmd = {29'b0, prmd_PIE, prmd_PPLV};

  // ESTAT
  wire [31:0] estat;
  reg [1:0] estat_IS_1_0;
  reg [7:0] estat_IS_9_2; // R
  reg estat_IS_11;     // R
  reg estat_IS_12;   // R
  reg [5:0] estat_Ecode; // R
  reg [8:0] estat_EsubCode; // R
  assign estat = {1'b0, estat_EsubCode, estat_Ecode, 3'b0, estat_IS_12, estat_IS_11, 1'b0, estat_IS_9_2, estat_IS_1_0};

  // ERA
  reg [31:0] era;

  // EENTRY
  wire [31:0] eentry;
  reg [25:0] eentry_VA;
  assign eentry = {eentry_VA, 6'b0};



  // SAVE0-3
  reg [31:0] save0;
  reg [31:0] save1;
  reg [31:0] save2;
  reg [31:0] save3;

  always@(posedge clk)
  begin
    if(~resetn)
    begin
    end
    else if(we)
    begin

    end
  end



  //-------------------------csr读取-------------------------------
  assign rdata = (csr_num == `CRMD) ? crmd :
         (csr_num == `PRMD) ? prmd :
         (csr_num == `ESTAT) ? estat :
         (csr_num == `ERA) ? era :
         (csr_num == `EENTRY) ? eentry :
         (csr_num == `SAVE0) ? save0 :
         (csr_num == `SAVE1) ? save1 :
         (csr_num == `SAVE2) ? save2 :
         (csr_num == `SAVE3) ? save3 :
         32'b0;

  //------------------------csr to IF_stage------------------------
    assign CSR_2_IF_pc = EXC_signal ? EXC_pc : 
                        ERTN_signal ? eentry :
                        32'b0;
    
  //-------------------寄存器时序电路---------------------------

  // CRMD
  always@(posedge clk)
  begin
    if(~resetn)
    begin
      crmd_PLV <= 2'b0;
      crmd_IE <= 1'b0;
      crmd_DA <= 1'b1;
      crmd_PG <= 1'b0;
      crmd_DATF <= 2'b0;
      crmd_DATM <= 2'b0;
    end
    else if(EXC_signal)
    begin
      crmd_PLV <= 2'b0;
      crmd_IE <= 1'b0;
    end
    else if(ERTN_signal)
    begin
      crmd_PLV <= prmd_PPLV;
      crmd_IE <= prmd_PIE;
      if(EXC_ecode == 8'h3F)
      begin
        crmd_DA <= 1'b0;
        crmd_PG <= 1'b1;
        crmd_DATF <= 2'b01;
        crmd_DATM <= 2'b01;
      end
    end
    else if(we && (csr_num == `CRMD))
    begin
      crmd_PLV <= wmask[1:0] & wdata[1:0] | ~wmask[1:0] & crmd_PLV;
      crmd_IE <= wmask[2] & wdata[2] | ~wmask[2] & crmd_IE;
      crmd_DA <= wmask[3] & wdata[3] | ~wmask[3] & crmd_DA;
      crmd_PG <= wmask[4] & wdata[4] | ~wmask[4] & crmd_PG;
      crmd_DATF <= wmask[6:5] & wdata[6:5] | ~wmask[6:5] & crmd_DATF;
      crmd_DATM <= wmask[8:7] & wdata[8:7] | ~wmask[8:7] & crmd_DATM;
    end
  end

  // PRMD
  always@(posedge clk)
  begin
    if(EXC_signal)
    begin
      prmd_PPLV <= crmd_PLV;
      prmd_PIE <= crmd_IE;
    end
    else if(we && (csr_num == `PRMD))
    begin
      prmd_PPLV <= wmask[1:0] & wdata[1:0] | ~wmask[1:0] & prmd_PPLV;
      prmd_PIE <= wmask[2] & wdata[2] | ~wmask[2] & prmd_PIE;
    end
  end


  // ESTAT
  always@(posedge clk)
  begin
    if(~resetn)
    begin
      estat_IS_1_0 <= 2'b0;
    end
    else if(EXC_signal)
    begin
      estat_Ecode <= EXC_ecode;
      estat_EsubCode <= EXC_esubcode;
    end
    else if(we && (csr_num == `ESTAT))
    begin
      estat_IS_1_0 <= wmask[1:0] & wdata[1:0] | ~wmask[1:0] & estat_IS_1_0;
    end
  end

  // ERA
    always@(posedge clk)
    begin
        if(EXC_signal)
        begin
            era <= EXC_pc;
        end
        else if(we && (csr_num == `ERA))
        begin
            era <= wmask & wdata | ~wmask & era;
        end
    end


  // EENTRY
    always@(posedge clk)
    begin
        if(EXC_signal)
        begin
            eentry_VA <= EXC_pc[31:6];
        end
        else if(we && (csr_num == `EENTRY))
        begin
            eentry_VA <= wmask[31:6] & wdata[31:6] | ~wmask[31:6] & eentry_VA;
        end
    end


  // SAVE0-3
    always@(posedge clk)
    begin
        if(we && (csr_num == `SAVE0))
        begin
            save0 <= wmask & wdata | ~wmask & save0;
        end
        else if(we && (csr_num == `SAVE1))
        begin
            save1 <= wmask & wdata | ~wmask & save1;
        end
        else if(we && (csr_num == `SAVE2))
        begin
            save2 <= wmask & wdata | ~wmask & save2;
        end
        else if(we && (csr_num == `SAVE3))
        begin
            save3 <= wmask & wdata | ~wmask & save3;
        end
    end

endmodule
