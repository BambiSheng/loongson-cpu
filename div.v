module Div(
    /*
    32位除法器
    
    div_clk: 除法器的时钟信号
    resetn: 除法器的复位信号(取反)
    div: 除法器使能信号
    div_signed: 除法器是否有符号
    x: 被除数
    y: 除数
    s: 商
    r: 余数
    complete: 除法完成信号
    */
    input  wire        div_clk,
    input  wire        resetn,
    input  wire        div,
    input  wire        div_signed,
    input  wire [31:0] x,
    input  wire [31:0] y,
    output wire  [31:0] s,
    output wire  [31:0] r,
    output wire         complete
  );

  reg [5:0] count = 0;
  wire sign_r;
  wire sign_s;
  wire [31:0] abs_x;
  wire [31:0] abs_y;

  reg [32:0] temp_x;
  wire [32:0] temp_y;
  reg [31:0] temp_s = 0;
  wire [31:0] temp_r;

  // 完成信号
  assign complete = (count == 33);

  // 1.根据被除数和除数确定商和余数的符号,并计算被除数和除数的绝对值
  assign sign_r = x[31] & div_signed;
  assign sign_s = (x[31] ^ y[31]) & div_signed;
  assign abs_x = (div_signed & x[31]) ? (~x + 1'b1) : x;
  assign abs_y = (div_signed & y[31]) ? (~y + 1'b1) : y;

  // 2.迭代运算得到商和余数的绝对值

  // 更新count, 初始化temp_y
  assign temp_y = {1'b0, abs_y};
  always @(posedge div_clk)
  begin
    if (!resetn)
    begin
      count <= 0;
    end
    else if (div)
    begin
      if (complete)
      begin
        count <= 0;
      end
      else
      begin
        count <= count + 1;
      end
    end
  end

  // 进行迭代
  wire [32:0] temp_result;
  assign temp_result = temp_x - temp_y;
  always @(posedge div_clk)
  if (!resetn)
  begin
    temp_s <= 0;
    temp_x <= 0;
  end
  else if (div)
  begin
    if(count == 0)
    begin
      temp_x <= {32'b0, abs_x[31]};
    end
    else if(!complete)
    begin
      temp_x <= {(~temp_result[32]) ? temp_result: temp_x, abs_x[31-count]};
      temp_s[32 - count] <= ~temp_result[32];
    end
  end

  // 计算余数
  assign temp_r = abs_x - temp_s * abs_y;

  // 3. 调整最终的商和余数
  assign s = div_signed & sign_s ? (~temp_s + 1'b1) : temp_s;
  assign r = div_signed & sign_r ? (~temp_r + 1'b1) : temp_r;

endmodule
