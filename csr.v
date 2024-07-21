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
    EXC_vaddr: 异常访存地址

    CSR_2_IF_pc: csr到IF_stage的pc
    INT_signal: 中断信号
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
    input wire [31:0] EXC_vaddr,

    output wire [31:0] CSR_2_IF_pc,
    output wire INT_signal
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

  // ECFG
  wire [31:0] ecfg;
  reg [9:0] efcg_LIE_9_0;
  reg [1:0] efcg_LIE_12_11;
  assign ecfg = {19'b0, efcg_LIE_12_11, 1'b0, efcg_LIE_9_0};

  // BADV
  reg [31:0] badv;

  // TID
  reg [31:0] tid;

  // TCFG: set n = 32
  wire [31:0] tcfg;
  reg tcfg_En;
  reg tcfg_Periodic;
  reg [`TCFG_N - 3:0] tcfg_InitVal;
  assign tcfg = {tcfg_InitVal, tcfg_Periodic, tcfg_En};

  // TVAL
  reg [`TCFG_N - 1:0] tval;

  // TICLR
  wire [31:0] ticlr;
  assign ticlr = 32'b0;

  //-------------------------中断信号-------------------------------
  wire [7:0] HW_int;
  wire TI_int;
  wire IPI_int;
  assign HW_int = 8'b0;
  assign IPI_int = 1'b0;
  assign INT_signal = (ecfg[12:0] & estat[12:0]) && crmd_IE;


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
         (csr_num == `ECFG) ? ecfg :
         (csr_num == `BADV) ? badv :
         (csr_num == `TID) ? tid :
         (csr_num == `TCFG) ? tcfg :
         (csr_num == `TVAL) ? tval :
         (csr_num == `TICLR) ? ticlr :
         32'b0;

  //------------------------csr to IF_stage------------------------
  assign CSR_2_IF_pc = EXC_signal ? eentry :
         ERTN_signal ? era :
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
    else if(we && (csr_num == `ESTAT))
    begin
      estat_IS_1_0 <= wmask[1:0] & wdata[1:0] | ~wmask[1:0] & estat_IS_1_0;
    end

    if(EXC_signal)
    begin
      estat_Ecode <= EXC_ecode;
      estat_EsubCode <= EXC_esubcode;
    end

    // 处理定时器中断
    if(tval == 0)
    begin
      estat_IS_11 <= 1'b1;
    end
    else if(we && (csr_num == `TICLR) && wmask[0] && wdata[0])
    begin
      estat_IS_11 <= 1'b0; // 清除定时器中断
    end

    estat_IS_9_2 <= HW_int;
    estat_IS_12 <= IPI_int;
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
    if(we && (csr_num == `EENTRY))
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
  // ECFG
  always@(posedge clk)
  begin
    if(~resetn)
    begin
      efcg_LIE_9_0 <= 10'b0;
      efcg_LIE_12_11 <= 2'b0;
    end
    else if(we && (csr_num == `ECFG))
    begin
      efcg_LIE_9_0 <= wmask[9:0] & wdata[9:0] | ~wmask[9:0] & efcg_LIE_9_0;
      efcg_LIE_12_11 <= wmask[12:11] & wdata[12:11] | ~wmask[12:11] & efcg_LIE_12_11;
    end
  end

  // BADV
  always@(posedge clk)
  begin
    if(EXC_signal && EXC_ecode == 8'h09)
    begin
      badv <= EXC_vaddr;
    end
    else if (EXC_signal && EXC_ecode == 8'h08)
    begin
      badv <= (EXC_esubcode == 9'h00) ? EXC_pc : EXC_vaddr;
    end
    else if(we && (csr_num == `BADV))
    begin
      badv <= wmask & wdata | ~wmask & badv;
    end
  end

  // TID
  always@(posedge clk)
  begin
    if(we && (csr_num == `TID))
    begin
      tid <= wmask & wdata | ~wmask & tid;
    end
  end

  // TCFG
  always@(posedge clk)
  begin
    if(~resetn)
    begin
      tcfg_En <= 1'b0;
    end
    else if(we && (csr_num == `TCFG))
    begin
      tcfg_En <= wmask[0] & wdata[0] | ~wmask[0] & tcfg_En;
      tcfg_Periodic <= wmask[1] & wdata[1] | ~wmask[1] & tcfg_Periodic;
      tcfg_InitVal <= wmask[`TCFG_N-1:2] & wdata[`TCFG_N-1:2] | ~wmask[`TCFG_N-1:2] & tcfg_InitVal;
    end
  end

  // TVAL
  parameter TVAL_MAX = 32'hfffffff >> (32 - `TCFG_N);
  always@(posedge clk)
  begin
    if(~resetn)
    begin
      tval <= TVAL_MAX;
    end
    else if(we && (csr_num == `TCFG) && wmask[0] && wdata[0]) // 定时器使能
    begin
      tval <= {wmask[`TCFG_N-1:2] & wdata[`TCFG_N-1:2] | ~wmask[`TCFG_N-1:2] & tcfg_InitVal, 2'b0};
    end
    else if(tval != TVAL_MAX && tcfg_En)
    begin
      if(tval != 0)
      begin
        tval <= tval - 1;
      end
      else if(tcfg_Periodic)
      begin
        tval <= {tcfg_InitVal, 2'b0};
      end
      else
      begin
        tval <= TVAL_MAX;
      end
    end
  end

endmodule
