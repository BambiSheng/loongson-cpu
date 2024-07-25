`include "mycpu.h"
module ID_stage (
    /*
  ID_stage模块

  clk: 时钟
  resetn: 复位信号
  IF_ID_valid: IF_ID是否有效
  ID_allowin: 允许ID_stage接收数据
  br_bus: 分支总线
  IF_ID_bus: IF_ID总线
  EX_allowin: 允许EX_stage接收数据
  ID_EX_valid: ID_EX是否有效
  ID_EX_bus: ID_EX总线

  ID_except_bus: ID异常总线

  WB_rf_bus: WB数据转发总线
  MEM_rf_bus: MEM数据转发总线
  EX_rf_bus: EX数据转发总线

  WB_EXC_signal: WB异常信号
  INT_signal: 中断信号
  */
    input  wire                   clk,
    input  wire                   resetn,
    input  wire                   IF_ID_valid,
    output wire                   ID_allowin,
    output wire [           33:0] br_bus,
    input  wire [`IF_ID_LEN -1:0] IF_ID_bus,
    input  wire                   EX_allowin,
    output wire                   ID_EX_valid,
    output wire [`ID_EX_LEN -1:0] ID_EX_bus,
    output wire [84:0] ID_except_bus,
    input wire [37:0] WB_rf_bus,   // {WB_rf_we,WB_rf_we, WB_rf_waddr, WB_rf_wdata}
    input wire [39:0] MEM_rf_bus,  // {MEM_csr_re,MEM_rf_we, MEM_rf_waddr, MEM_rf_wdata}
    input wire [39:0] EX_rf_bus,    // {EX_csr_re,EX_res_from_mem, EX_rf_we, EX_rf_waddr, EX_alu_result}

    input wire WB_EXC_signal,
    input wire INT_signal
);

  wire        ID_ready_go;
  reg         ID_valid;
  reg  [31:0] ID_inst;
  wire        ID_stall;

  wire [18:0] ID_alu_op;
  wire [31:0] ID_alu_src1;
  wire [31:0] ID_alu_src2;
  wire        ID_src1_is_pc;
  wire        ID_src2_is_imm;
  wire        ID_res_from_MEM;  // 是否需要从MEM阶段传回数据
  reg  [31:0] ID_pc;
  wire [31:0] ID_rkd_value;
  wire [ 7:0] ID_mem_inst;  // 是否读/写内存

  wire        dst_is_r1;  // 目的寄存器是否为r1
  wire        dst_is_rj;  // 目的寄存器是否为rj
  wire        gr_we;  // 是否写寄存器
  wire        src_reg_is_rd;  // 源寄存器是否为rd
  wire        rj_eq_rd;  // rj是否等于rd
  wire [ 4:0] dest;
  wire [31:0] rj_value;
  wire [31:0] rkd_value;
  wire [31:0] imm;

  wire [31:0] br_offs;  // 分支偏移量
  wire [31:0] jirl_offs;  // 跳转偏移量
  wire        br_taken;  // 是否分支跳转
  wire [31:0] br_target;  // 分支目标地址
  wire        br_stall;  // 分支冲突

  wire [ 5:0] op_31_26;
  wire [ 3:0] op_25_22;
  wire [ 1:0] op_21_20;
  wire [ 4:0] op_19_15;
  wire [ 4:0] rd;
  wire [ 4:0] rj;
  wire [ 4:0] rk;
  wire [11:0] i12;
  wire [19:0] i20;
  wire [15:0] i16;
  wire [25:0] i26;

  wire [63:0] op_31_26_d;
  wire [15:0] op_25_22_d;
  wire [ 3:0] op_21_20_d;
  wire [31:0] op_19_15_d;

  wire        inst_add_w;
  wire        inst_sub_w;
  wire        inst_slti;
  wire        inst_slt;
  wire        inst_sltui;
  wire        inst_sltu;
  wire        inst_nor;
  wire        inst_and;
  wire        inst_andi;
  wire        inst_or;
  wire        inst_ori;
  wire        inst_xor;
  wire        inst_xori;
  wire        inst_sll_w;
  wire        inst_slli_w;
  wire        inst_srl_w;
  wire        inst_srli_w;
  wire        inst_sra_w;
  wire        inst_srai_w;
  wire        inst_addi_w;
  wire        inst_ld_w;
  wire        inst_st_w;
  wire        inst_jirl;
  wire        inst_b;
  wire        inst_bl;
  wire        inst_beq;
  wire        inst_bne;
  wire        inst_lu12i_w;
  wire        inst_pcaddul2i;
  wire        inst_mul_w;
  wire        inst_mulh_w;
  wire        inst_mulh_wu;
  wire        inst_div_w;
  wire        inst_div_wu;
  wire        inst_mod_w;
  wire        inst_mod_wu;
  //added in exp11
  wire        inst_blt;
  wire        inst_bge;
  wire        inst_bltu;
  wire        inst_bgeu;
  wire        inst_ld_b;
  wire        inst_ld_h;
  wire        inst_ld_bu;
  wire        inst_ld_hu;
  //added in exp12
  wire        inst_csrrd;
  wire        inst_csrwr;
  wire        inst_csrxchg;
  wire        inst_ertn;
  wire        inst_syscall;
  //added in exp13
  wire        inst_rdcntvl;
  wire        inst_rdcntvh;
  wire        inst_rdcntid;
  
  wire        inst_break;
  
  wire        INST_EXIST; // 判断指令是否存在
  
  wire        need_ui5;  // 是否需要无符号立即数5位  
  wire        need_ui12;  // 是否需要无符号立即数12位
  wire        need_si12;  // 是否需要有符号立即数12位
  wire        need_si16;  // 是否需要有符号立即数16位
  wire        need_si20;  // 是否需要有符号立即数20位
  wire        need_si26;  // 是否需要有符号立即数26位
  wire        src2_is_4;  // PC+4


  wire [ 4:0] rf_raddr1;
  wire [31:0] rf_rdata1;
  wire [ 4:0] rf_raddr2;
  wire [31:0] rf_rdata2;

  wire        hazard_r1_wb;  // 写回数据r1冲突
  wire        hazard_r2_wb;  // 写回数据r2冲突
  wire        hazard_r1_mem;  // 访存数据r1冲突 
  wire        hazard_r2_mem;  // 访存数据r2冲突
  wire        hazard_r1_ex;  // 执行数据r1冲突
  wire        hazard_r2_ex;  // 执行数据r2冲突
  wire        need_r1;  // 是否需要读取r1
  wire        need_r2;  // 是否需要读取r2

  //传回信号定义
  wire        WB_rf_we;
  wire [ 4:0] WB_rf_waddr;
  wire [31:0] WB_rf_wdata;

  wire        MEM_rf_we;
  wire [ 4:0] MEM_rf_waddr;
  wire [31:0] MEM_rf_wdata;
  wire        MEM_res_from_mem;
  wire        MEM_csr_re  ;

  wire        EX_rf_we;
  wire [ 4:0] EX_rf_waddr;
  wire [31:0] EX_rf_wdata;
  wire        EX_res_from_mem;
  wire        EX_csr_re  ;

  wire        ID_rf_we;
  wire [ 4:0] ID_rf_waddr;

  reg        ID_exc_ADEF;
  wire        ID_exc_syscall;
  wire        ID_exc_break;
  wire        ID_exc_INE;
  wire        ID_exc_ERTN;
  wire        ID_exc_INT;

  wire        ID_csr_re;
  wire [13:0] ID_csr_num;
  wire        ID_csr_we;
  wire [31:0] ID_csr_wmask;
  wire [31:0] ID_csr_wvalue;
  wire [ 6:0] ID_rf_bus;

  wire [ 1:0] ID_cnt_inst;

  //------------------------------state control signal---------------------------------------
  assign ID_ready_go = ~ID_stall;
  assign ID_allowin = ~ID_valid | ID_ready_go & EX_allowin;
  assign ID_stall    = (EX_res_from_mem | EX_csr_re) & (hazard_r1_ex & need_r1 | hazard_r2_ex & need_r2)|
                       (MEM_res_from_mem | MEM_csr_re)& (hazard_r1_mem & need_r1| hazard_r2_mem & need_r2)                               ;   // load-use冲突
  assign br_stall    = ID_stall & (inst_jirl   | inst_b      | inst_bl     | inst_blt   | inst_bge    | inst_bltu  |
                                   inst_bgeu   | inst_beq    | inst_bne ); // 分支冲突判断
  assign ID_EX_valid = ID_valid & ID_ready_go;
  always @(posedge clk) begin
    if (~resetn) ID_valid <= 1'b0;
    else if (WB_EXC_signal) ID_valid <= 1'b0;
    else if (br_taken) ID_valid <= 1'b0;
    else if (ID_allowin) ID_valid <= IF_ID_valid;
  end

  //------------------------------if and id state interface---------------------------------------
  always @(posedge clk) begin
    if (~resetn) {ID_exc_ADEF, ID_inst, ID_pc} <= 64'b0;
    if (IF_ID_valid & ID_allowin) begin
      {ID_exc_ADEF, ID_inst, ID_pc} <= IF_ID_bus;
    end
  end

  //提前判断分支跳转条件
  assign rj_eq_rd = (rj_value == rkd_value);
  assign rj_lt_rd = ($signed(rj_value) < $signed(rkd_value));
  assign rj_lt_rd_u = ($unsigned(rj_value) < $unsigned(rkd_value));
  assign br_taken = (inst_beq  &&  rj_eq_rd
                    || inst_bne  && !rj_eq_rd
                    || inst_jirl
                    || inst_bl
                    || inst_b
                    || inst_blt && rj_lt_rd
                    || inst_bge && !rj_lt_rd
                    || inst_bltu && rj_lt_rd_u
                    || inst_bgeu && !rj_lt_rd_u
                    ) && ID_valid  && ~br_stall;    // 分支跳转条件
  assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || 
                      inst_blt || inst_bge || inst_bltu || inst_bgeu ) ? (ID_pc + br_offs) :(rj_value + jirl_offs);       // 分支目标地址
  assign br_bus = {br_stall,br_taken, br_target};

  //------------------------------decode instruction---------------------------------------

  assign op_31_26 = ID_inst[31:26];
  assign op_25_22 = ID_inst[25:22];
  assign op_21_20 = ID_inst[21:20];
  assign op_19_15 = ID_inst[19:15];

  assign rd = ID_inst[4:0];
  assign rj = ID_inst[9:5];
  assign rk = ID_inst[14:10];

  assign i12 = ID_inst[21:10];
  assign i20 = ID_inst[24:5];
  assign i16 = ID_inst[25:10];
  assign i26 = {ID_inst[9:0], ID_inst[25:10]};

  decoder_6_64 u_dec0 (
      .in (op_31_26),
      .out(op_31_26_d)
  );
  decoder_4_16 u_dec1 (
      .in (op_25_22),
      .out(op_25_22_d)
  );
  decoder_2_4 u_dec2 (
      .in (op_21_20),
      .out(op_21_20_d)
  );
  decoder_5_32 u_dec3 (
      .in (op_19_15),
      .out(op_19_15_d)
  );

  assign inst_add_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
  assign inst_sub_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
  assign inst_slt = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
  assign inst_sltu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
  assign inst_nor = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
  assign inst_and = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
  assign inst_or = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
  assign inst_xor = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];

  assign inst_sll_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
  assign inst_srl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
  assign inst_sra_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];

  assign inst_mul_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
  assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
  assign inst_mulh_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
  assign inst_div_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
  assign inst_mod_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
  assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
  assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

  assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
  assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
  assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
  assign inst_slti = op_31_26_d[6'h00] & op_25_22_d[4'h8];
  assign inst_sltui = op_31_26_d[6'h00] & op_25_22_d[4'h9];
  assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
  assign inst_andi = op_31_26_d[6'h00] & op_25_22_d[4'hd];
  assign inst_ori = op_31_26_d[6'h00] & op_25_22_d[4'he];
  assign inst_xori = op_31_26_d[6'h00] & op_25_22_d[4'hf];
  assign inst_ld_w = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
  assign inst_st_w = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
  assign inst_jirl = op_31_26_d[6'h13];
  assign inst_b = op_31_26_d[6'h14];
  assign inst_bl = op_31_26_d[6'h15];
  assign inst_beq = op_31_26_d[6'h16];
  assign inst_bne = op_31_26_d[6'h17];
  assign inst_lu12i_w = op_31_26_d[6'h05] & ~ID_inst[25];
  assign inst_pcaddul2i = op_31_26_d[6'h07] & ~ID_inst[25];
  assign inst_blt = op_31_26_d[6'h18];
  assign inst_bge = op_31_26_d[6'h19];
  assign inst_bltu = op_31_26_d[6'h1a];
  assign inst_bgeu = op_31_26_d[6'h1b];
  assign inst_ld_b = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
  assign inst_ld_h = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
  assign inst_ld_bu = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
  assign inst_ld_hu = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
  assign inst_st_b = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
  assign inst_st_h = op_31_26_d[6'h0a] & op_25_22_d[4'h5];

  //added in exp12
  assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
  assign inst_csrrd = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'h00);
  assign inst_csrwr = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'h01);
  assign inst_csrxchg = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & ~inst_csrrd & ~inst_csrwr;

  assign inst_ertn    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] 
                      & (rk == 5'h0e) & (~|rj) & (~|rd);

  //added in exp13
  assign inst_rdcntvl = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rj == 5'h00);
  assign inst_rdcntvh = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h19) & (rj == 5'h00);
  assign inst_rdcntid = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rd == 5'h00);

  assign inst_break   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];

  assign INST_EXIST   = // 算术 & 逻辑
                        inst_add_w  | inst_sub_w  | inst_slti   | inst_slt   | inst_sltui  | inst_sltu  |
                        inst_nor    | inst_and    | inst_andi   | inst_or    | inst_ori    | inst_xor   |
                        inst_xori   | inst_sll_w  | inst_slli_w | inst_srl_w | inst_srli_w | inst_sra_w | 
                        inst_srai_w | inst_addi_w | inst_mul_w  | inst_mulh_w | inst_mulh_wu| inst_div_w |
                        inst_div_wu | inst_mod_w |inst_mod_wu |
                        // 访存
                        inst_ld_b   | inst_ld_h   | inst_ld_w   | inst_ld_bu | inst_ld_hu  | inst_st_b  |
                        inst_st_h   | inst_st_w |
                        // 分支
                        inst_jirl   | inst_b      | inst_bl     | inst_blt   | inst_bge    | inst_bltu  |
                        inst_bgeu   | inst_beq    | inst_bne |
                        // 其他
                        inst_csrrd  | inst_csrwr  | inst_csrxchg| inst_ertn  | inst_syscall| inst_break |
                        inst_rdcntid| inst_rdcntvh| inst_rdcntvl| inst_lu12i_w| inst_pcaddul2i; 

  //aluop 译码：0 add, 1 sub, 2 slt, 3 sltu, 4 and, 5 nor, 6 or, 7 xor, 8 sll, 9 srl, 10 sra, 11 lui
  //12 mul, 13 mulh, 14 mulhu, 15 div, 16 divu, 17 mod, 18 modu

  assign ID_alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                        | inst_jirl | inst_bl | inst_pcaddul2i
                        | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h;
  assign ID_alu_op[1] = inst_sub_w | inst_bne | inst_beq;
  assign ID_alu_op[2] = inst_slt | inst_slti | inst_blt | inst_bge;
  assign ID_alu_op[3] = inst_sltu | inst_sltui | inst_bltu | inst_bgeu;
  assign ID_alu_op[4] = inst_and | inst_andi;
  assign ID_alu_op[5] = inst_nor;
  assign ID_alu_op[6] = inst_or | inst_ori;
  assign ID_alu_op[7] = inst_xor | inst_xori;
  assign ID_alu_op[8] = inst_slli_w | inst_sll_w;
  assign ID_alu_op[9] = inst_srli_w | inst_srl_w;
  assign ID_alu_op[10] = inst_srai_w | inst_sra_w;
  assign ID_alu_op[11] = inst_lu12i_w;
  assign ID_alu_op[12] = inst_mul_w;
  assign ID_alu_op[13] = inst_mulh_w;
  assign ID_alu_op[14] = inst_mulh_wu;
  assign ID_alu_op[15] = inst_div_w;
  assign ID_alu_op[16] = inst_div_wu;
  assign ID_alu_op[17] = inst_mod_w;
  assign ID_alu_op[18] = inst_mod_wu;


  assign need_ui5 = inst_slli_w | inst_srli_w | inst_srai_w;
  assign need_ui12 = inst_andi | inst_ori | inst_xori;
  assign need_si12 = inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui |
                     inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h;
  assign need_si16 = inst_jirl | inst_beq | inst_bne;
  assign need_si20 = inst_lu12i_w | inst_pcaddul2i;
  assign need_si26 = inst_b | inst_bl;
  assign src2_is_4 = inst_jirl | inst_bl;

  assign imm = src2_is_4 ? 32'h4                      :
                need_si20 ? {i20[19:0], 12'b0}         :
                (need_ui5 || need_si12) ? {{20{i12[11]}}, i12[11:0]} :
                {20'b0, i12[11:0]};

  assign br_offs = need_si26 ? {{4{i26[25]}}, i26[25:0], 2'b0} : {{14{i16[15]}}, i16[15:0], 2'b0};

  assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

  assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_blt | inst_bge |
                         inst_bltu| inst_bgeu| inst_st_b | inst_st_h | inst_csrwr | inst_csrxchg;          // 源寄存器是否为rd

  assign ID_src1_is_pc = inst_jirl | inst_bl | inst_pcaddul2i;  // 源寄存器1是否为PC

  assign ID_src2_is_imm   = inst_slli_w |   
                        inst_srli_w |
                        inst_srai_w |
                        inst_addi_w |
                        inst_ld_w   |
                        inst_st_w   |
                        inst_lu12i_w|
                        inst_jirl   |
                        inst_bl     |
                        inst_pcaddul2i|
                        inst_andi   |
                        inst_ori    |
                        inst_xori   |
                        inst_slti   |
                        inst_sltui  |
                        inst_ld_b   |
                        inst_ld_h   |
                        inst_ld_bu  |
                        inst_ld_hu  |
                        inst_st_b   |
                        inst_st_h;  // 源寄存器2是否为立即数

  assign ID_alu_src1 = ID_src1_is_pc ? ID_pc[31:0] : rj_value;
  assign ID_alu_src2 = ID_src2_is_imm ? imm : rkd_value;

  assign ID_rkd_value = rkd_value;
  assign ID_res_from_MEM = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
  assign dst_is_r1 = inst_bl;
  assign dst_is_rj = inst_rdcntid;
  assign gr_we = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bge &
                 ~inst_bltu & ~inst_bgeu& ~inst_st_b & ~inst_st_h & ~inst_syscall;  // 是否写寄存器
  assign ID_mem_inst = {
    inst_st_w, inst_st_h, inst_st_b, inst_ld_w, inst_ld_b, inst_ld_h, inst_ld_bu, inst_ld_hu
  };
  assign ID_cnt_inst = {
    inst_rdcntvl, inst_rdcntvh
  };

  assign dest = dst_is_r1 ? 5'd1 :
                dst_is_rj ? rj   : rd;

  //------------------------------regfile control---------------------------------------
  assign rf_raddr1 = rj;
  assign rf_raddr2 = src_reg_is_rd ? rd : rk;
  assign ID_rf_we = gr_we;
  assign ID_rf_waddr = dest;
  assign ID_rf_bus = {ID_csr_re, ID_rf_we, ID_rf_waddr};
  //写回、访存、执行阶段传回数据处理

  assign {WB_rf_we, WB_rf_waddr, WB_rf_wdata} = WB_rf_bus;
  assign {MEM_res_from_mem,MEM_csr_re,MEM_rf_we, MEM_rf_waddr, MEM_rf_wdata} = MEM_rf_bus;
  assign {EX_csr_re,EX_res_from_mem, EX_rf_we, EX_rf_waddr, EX_rf_wdata} = EX_rf_bus;

  regfile u_regfile (
      .clk   (clk),
      .raddr1(rf_raddr1),
      .rdata1(rf_rdata1),
      .raddr2(rf_raddr2),
      .rdata2(rf_rdata2),
      .we    (WB_rf_we),
      .waddr (WB_rf_waddr),
      .wdata (WB_rf_wdata)
  );
  // 冲突：写使能 + 写地址不为0号寄存器 + 写地址与当前读寄存器地址相同
  assign hazard_r1_wb = (|rf_raddr1) & (rf_raddr1 == WB_rf_waddr) & WB_rf_we;
  assign hazard_r2_wb = (|rf_raddr2) & (rf_raddr2 == WB_rf_waddr) & WB_rf_we;
  assign hazard_r1_mem = (|rf_raddr1) & (rf_raddr1 == MEM_rf_waddr) & MEM_rf_we;
  assign hazard_r2_mem = (|rf_raddr2) & (rf_raddr2 == MEM_rf_waddr) & MEM_rf_we;
  assign hazard_r1_ex = (|rf_raddr1) & (rf_raddr1 == EX_rf_waddr) & EX_rf_we;
  assign hazard_r2_ex = (|rf_raddr2) & (rf_raddr2 == EX_rf_waddr) & EX_rf_we;
  assign need_r1 = ~ID_src1_is_pc & (|ID_alu_op);
  assign need_r2 = ~ID_src2_is_imm & (|ID_alu_op);
  // 数据冲突时处理有先后顺序，以最后一次更新为准
  assign rj_value  =  hazard_r1_ex ? EX_rf_wdata:
                        hazard_r1_mem ? MEM_rf_wdata:
                        hazard_r1_wb  ? WB_rf_wdata : rf_rdata1;
  assign rkd_value =  hazard_r2_ex ? EX_rf_wdata:
                        hazard_r2_mem ? MEM_rf_wdata:
                        hazard_r2_wb  ? WB_rf_wdata : rf_rdata2;
  
                    
  assign ID_csr_re = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid;
  assign ID_csr_we = inst_csrwr | inst_csrxchg;
  assign ID_csr_wmask = {32{inst_csrxchg}} & rj_value | {32{inst_csrwr}};
  assign ID_csr_wvalue = rkd_value;
  assign ID_csr_num = {14{inst_rdcntid}} & `TID | {14{~inst_rdcntid}} & ID_inst[23:10];

  assign ID_exc_syscall = inst_syscall;
  assign ID_exc_break = inst_break;
  assign ID_exc_INE = ~INST_EXIST;
  assign ID_exc_INT = INT_signal;

  assign ID_except_bus = {
                          ID_exc_ADEF, ID_exc_INE, ID_exc_INT, ID_exc_break, 
                          ID_csr_num, ID_csr_wmask, ID_csr_wvalue, ID_exc_syscall, inst_ertn, ID_csr_we};
  //------------------------------ID_EX bus---------------------------------------
  assign ID_EX_bus = {
    ID_alu_op,  //19 bit
    ID_res_from_MEM,  //1  bit
    ID_alu_src1,  //32 bit
    ID_alu_src2,  //32 bit

    ID_mem_inst,  //8  bit
    ID_rf_we,  //1  bit
    ID_rf_waddr,  //5  bit

    ID_rkd_value,  //32 bit
    ID_pc,  //32 bit

    ID_csr_re,  //1  bit

    ID_cnt_inst  //2  bit
  };

endmodule