`include "mycpu.h"
module mycpu_top(
    input  aclk   ,
    input  aresetn,
    // read req channel
    output [ 3:0] arid   , // 读请求ID
    output [31:0] araddr , // 读请求地址
    output [ 7:0] arlen  , // 读请求传输长度（数据传输拍数）
    output [ 2:0] arsize , // 读请求传输大小（数据传输每拍的字节数）
    output [ 1:0] arburst, // 传输类型
    output [ 1:0] arlock , // 原子锁
    output [ 3:0] arcache, // Cache属性
    output [ 2:0] arprot , // 保护属性
    output        arvalid, // 读请求地址有效
    input         arready, // 读请求地址握手信号
    // read response channel
    input [ 3:0]  rid    , // 读请求ID号，同一请求rid与arid一致
    input [31:0]  rdata  , // 读请求读出的数据
    input [ 1:0]  rresp  , // 读请求是否完成                        [可忽略]
    input         rlast  , // 读请求最后一拍数据的指示信号           [可忽略]
    input         rvalid , // 读请求数据有效
    output        rready , // Master端准备好接受数据
    // write req channel
    output [ 3:0] awid   , // 写请求的ID号
    output [31:0] awaddr , // 写请求的地址
    output [ 7:0] awlen  , // 写请求传输长度（拍数）
    output [ 2:0] awsize , // 写请求传输每拍字节数
    output [ 1:0] awburst, // 写请求传输类型
    output [ 1:0] awlock , // 原子锁
    output [ 3:0] awcache, // Cache属性
    output [ 2:0] awprot , // 保护属性
    output        awvalid, // 写请求地址有效
    input         awready, // Slave端准备好接受地址传输   
    // write data channel
    output [ 3:0] wid    , // 写请求的ID号
    output [31:0] wdata  , // 写请求的写数据
    output [ 3:0] wstrb  , // 写请求字节选通位
    output        wlast  , // 写请求的最后一拍数据的指示信号
    output        wvalid , // 写数据有效
    input         wready , // Slave端准备好接受写数据传输   
    // write response channel
    input  [ 3:0] bid    , // 写请求的ID号            [可忽略]
    input  [ 1:0] bresp  , // 写请求完成信号          [可忽略]
    input         bvalid , // 写请求响应有效
    output        bready , // Master端准备好接收响应信号
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

  wire                   ID_allowin;
  wire                   EX_allowin;
  wire                   MEM_allowin;
  wire                   WB_allowin;

  wire                   IF_ID_valid;
  wire                   ID_EX_valid;
  wire                   EX_MEM_valid;
  wire                   MEM_WB_valid;

  wire [           31:0] EX_pc;
  wire [           31:0] MEM_pc;

  wire [           39:0] EX_rf_bus;
  wire [           39:0] MEM_rf_bus;
  wire [           37:0] WB_rf_bus;

  wire [           33:0] br_bus;

  wire [`IF_ID_LEN -1:0] IF_ID_bus;
  wire [`ID_EX_LEN -1:0] ID_EX_bus;

  wire [            4:0] EX_mem_ld_inst;

  //csr wire
  wire [           13:0] csr_num;
  wire [           31:0] csr_rdata;
  wire                   we;
  wire [           31:0] csr_wdata;
  wire [           31:0] wmask;
  wire                   ERTN_signal;

  wire                   MEM_EXC_signal;
  wire                   WB_EXC_signal;


  wire [            5:0] EXC_ecode;
  wire [            8:0] EXC_esubcode;
  wire [           31:0] EXC_pc;

  wire [           31:0] CSR_2_IF_pc;
  wire                   INT_signal;

  wire [           84:0] ID_except_bus;
  wire [           85:0] EX_except_bus;
  wire [           85:0] MEM_except_bus;

  wire [           31:0] WB_vaddr;
  wire [           31:0] MEM_alu_result;

  //added in exp14
  wire                   EX_req;

  //added in exp15
    // inst sram interface
    wire        inst_sram_req;
    wire        inst_sram_wr;
    wire [ 1:0] inst_sram_size;
    wire [ 3:0] inst_sram_wstrb;
    wire [31:0] inst_sram_addr;
    wire [31:0] inst_sram_wdata;
    wire        inst_sram_addr_ok;
    wire        inst_sram_data_ok;
    wire [31:0] inst_sram_rdata;
    // data sram interface
    wire        data_sram_req;
    wire        data_sram_wr;
    wire [ 1:0] data_sram_size;
    wire [ 3:0] data_sram_wstrb;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire        data_sram_addr_ok;
    wire        data_sram_data_ok;
    wire [31:0] data_sram_rdata;

  bridge_sram_axi my_bridge_sram_axi(
    .aclk               (aclk               ),
    .aresetn            (aresetn            ),

    .arid               (arid               ),
    .araddr             (araddr             ),
    .arlen              (arlen              ),
    .arsize             (arsize             ),
    .arburst            (arburst            ),
    .arlock             (arlock             ),
    .arcache            (arcache            ),
    .arprot             (arprot             ),
    .arvalid            (arvalid            ),
    .arready            (arready            ),

    .rid                (rid                ),
    .rdata              (rdata              ),
    .rvalid             (rvalid             ),
    .rlast              (rlast              ),
    .rready             (rready             ),

    .awid               (awid               ),
    .awaddr             (awaddr             ),
    .awlen              (awlen              ),
    .awsize             (awsize             ),
    .awburst            (awburst            ),
    .awlock             (awlock             ),
    .awcache            (awcache            ),
    .awprot             (awprot             ),
    .awvalid            (awvalid            ),
    .awready            (awready            ),

    .wid                (wid                ),
    .wdata              (wdata              ),
    .wstrb              (wstrb              ),
    .wlast              (wlast              ),
    .wvalid             (wvalid             ),
    .wready             (wready             ),

    .bid                (bid                ),
    .bvalid             (bvalid             ),
    .bready             (bready             ),

    .inst_sram_req      (inst_sram_req      ),
    .inst_sram_wr       (inst_sram_wr       ),
    .inst_sram_size     (inst_sram_size     ),
    .inst_sram_addr     (inst_sram_addr     ),
    .inst_sram_wstrb    (inst_sram_wstrb    ),
    .inst_sram_wdata    (inst_sram_wdata    ),
    .inst_sram_addr_ok  (inst_sram_addr_ok  ),
    .inst_sram_data_ok  (inst_sram_data_ok  ),
    .inst_sram_rdata    (inst_sram_rdata    ),

    .data_sram_req      (data_sram_req      ),
    .data_sram_wr       (data_sram_wr       ),
    .data_sram_size     (data_sram_size     ),
    .data_sram_addr     (data_sram_addr     ),
    .data_sram_wstrb    (data_sram_wstrb    ),
    .data_sram_wdata    (data_sram_wdata    ),
    .data_sram_addr_ok  (data_sram_addr_ok  ),
    .data_sram_data_ok  (data_sram_data_ok  ),
    .data_sram_rdata    (data_sram_rdata    )
);

  IF_stage IF (
      .clk(aclk),
      .resetn(aresetn),

      .ID_allowin(ID_allowin),
      .br_bus(br_bus),
      .IF_ID_valid(IF_ID_valid),
      .IF_ID_bus(IF_ID_bus),

      .inst_sram_req(inst_sram_req),
      .inst_sram_wr(inst_sram_wr),
      .inst_sram_size(inst_sram_size),
      .inst_sram_wstrb(inst_sram_wstrb),
      .inst_sram_addr(inst_sram_addr),
      .inst_sram_wdata(inst_sram_wdata),
      .inst_sram_addr_ok(inst_sram_addr_ok),
      .inst_sram_data_ok(inst_sram_data_ok),
      .inst_sram_rdata(inst_sram_rdata),

      .WB_EXC_signal(WB_EXC_signal),
      .WB_ERTN_signal(ERTN_signal),
      .CSR_2_IF_pc(CSR_2_IF_pc),
      .axi_arid(arid)
  );

  ID_stage ID (
      .clk(aclk),
      .resetn(aresetn),

      .IF_ID_valid(IF_ID_valid),
      .ID_allowin(ID_allowin),
      .br_bus(br_bus),
      .IF_ID_bus(IF_ID_bus),

      .EX_allowin (EX_allowin),
      .ID_EX_valid(ID_EX_valid),
      .ID_EX_bus  (ID_EX_bus),

      .WB_rf_bus(WB_rf_bus),
      .MEM_rf_bus(MEM_rf_bus),
      .EX_rf_bus(EX_rf_bus),
      .ID_except_bus(ID_except_bus),

      .WB_EXC_signal(WB_EXC_signal | ERTN_signal),
      .INT_signal(INT_signal)
  );

  EX_stage EX (
      .clk(aclk),
      .resetn(aresetn),

      .EX_allowin (EX_allowin),
      .ID_EX_valid(ID_EX_valid),
      .ID_EX_bus  (ID_EX_bus),

      .MEM_allowin(MEM_allowin),
      .EX_rf_bus(EX_rf_bus),
      .EX_MEM_valid(EX_MEM_valid),
      .EX_pc(EX_pc),
      .EX_mem_ld_inst(EX_mem_ld_inst),
      .EX_req(EX_req),

      .data_sram_req(data_sram_req),
      .data_sram_wr(data_sram_wr),
      .data_sram_size(data_sram_size),
      .data_sram_wstrb(data_sram_wstrb),
      .data_sram_addr(data_sram_addr),
      .data_sram_wdata(data_sram_wdata),
      .data_sram_addr_ok(data_sram_addr_ok),
      .data_sram_rdata(data_sram_rdata),
      .data_sram_data_ok(data_sram_data_ok),
      
      .ID_except_bus(ID_except_bus),
      .EX_except_bus(EX_except_bus),

      .MEM_EXC_signal(MEM_EXC_signal),
      .WB_EXC_signal (WB_EXC_signal | ERTN_signal)
  );

  MEM_stage MEM (
      .clk(aclk),
      .resetn(aresetn),

      .MEM_allowin(MEM_allowin),
      .EX_rf_bus(EX_rf_bus),
      .EX_MEM_valid(EX_MEM_valid),
      .EX_pc(EX_pc),
      .EX_mem_ld_inst(EX_mem_ld_inst),
      .EX_req(EX_req),

      .WB_allowin(WB_allowin),
      .MEM_rf_bus(MEM_rf_bus),
      .MEM_WB_valid(MEM_WB_valid),
      .MEM_pc(MEM_pc),

      .WB_EXC_signal (WB_EXC_signal | ERTN_signal),
      .MEM_EXC_signal(MEM_EXC_signal),

      .MEM_except_bus(MEM_except_bus),
      .EX_except_bus (EX_except_bus),
      .MEM_alu_result(MEM_alu_result),

      .data_sram_rdata  (data_sram_rdata),
      .data_sram_data_ok(data_sram_data_ok)
  );

  WB_stage WB (
      .clk(aclk),
      .resetn(aresetn),

      .WB_allowin(WB_allowin),
      .MEM_rf_bus(MEM_rf_bus),
      .MEM_WB_valid(MEM_WB_valid),
      .MEM_pc(MEM_pc),

      .WB_rf_bus(WB_rf_bus),

      .debug_wb_pc(debug_wb_pc),
      .debug_wb_rf_we(debug_wb_rf_we),
      .debug_wb_rf_wnum(debug_wb_rf_wnum),
      .debug_wb_rf_wdata(debug_wb_rf_wdata),

      .csr_num(csr_num),
      .csr_rvalue(csr_rdata),
      .csr_we(we),
      .csr_wvalue(csr_wdata),
      .csr_wmask(wmask),
      .EXC_signal(WB_EXC_signal),
      .ERTN_signal(ERTN_signal),
      .WB_vaddr(WB_vaddr),
      .WB_pc(EXC_pc),
      .WB_ecode(EXC_ecode),
      .WB_esubcode(EXC_esubcode),

      .MEM_alu_result(MEM_alu_result),

      .MEM_except_bus(MEM_except_bus)
  );

  csr CSR (
      .clk(aclk),
      .resetn(aresetn),

      .csr_num(csr_num),
      .rdata  (csr_rdata),

      .we(we),
      .wdata(csr_wdata),
      .wmask(wmask),

      .EXC_signal(WB_EXC_signal),
      .ERTN_signal(ERTN_signal),
      .EXC_ecode(EXC_ecode),
      .EXC_esubcode(EXC_esubcode),
      .EXC_pc(EXC_pc),
      .EXC_vaddr(WB_vaddr),

      .CSR_2_IF_pc(CSR_2_IF_pc),
      .INT_signal (INT_signal)
  );
endmodule
