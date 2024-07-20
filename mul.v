// 全加器
module Adder (
    input   [63:0] a,
    input   [63:0] b,
    input   [63:0] c,
    output  [63:0] carry,
    output  [63:0] sum
);
    assign sum  = a ^ b ^ c;
    assign carry = {((a & b) | ((a ^ b) & c)), 1'b0} ;
endmodule

module booth (
    input    [2:0]in,    
    input    [63:0]  a1,
    input    [63:0]  a2,
    input    [63:0]  a3,
    input    [63:0]  a4,
    output   [63:0]  out
);
    assign out = 
                (in == 3'b001 || in == 3'b010)? a1:         // +[X]
                (in == 3'b011)? a2:                         // +2[X]
                (in == 3'b100)? a3:                         // -2[X]
                (in == 3'b101 || in == 3'b110)? a4:         // -[X]
                0;                                          // 0
    
endmodule

// 华莱士树乘法器 result = x * y
module Wallace_Mul (
    input           mul_clk,
    input           resetn,
    input           mul_signed,
    input   [31:0]  x,
    input   [31:0]  y,
    output  [63:0]  result
);

    // wire    [32:0]  flag_x_bu;
    // wire    [32:0]  flag_2x_bu;
    // wire    [32:0]  flag_neg_x_bu;
    // wire    [32:0]  flag_neg_2x_bu;
    // wire    [32:0]  flag_zero;
    wire    [63:0]  _x_bu;
    wire    [63:0]  _2x_bu;
    wire    [63:0]  _neg_x_bu;
    wire    [63:0]  _neg_2x_bu;

// 部分积(17个)
    wire    [63:0]  P [16:0];
// 补高位，使无符号数变成33位有符号数
    wire    [33:0]  y_signed;
    wire    [33:0]  y_left;
    wire    [33:0]  y_right;
    wire    [2:0]   flag  [16:0];

    assign y_signed = {{2{y[31] & mul_signed}}, y};
    assign y_left = {1'b0, y_signed[33:1]};
    assign y_right = {y_signed[32:0], 1'b0};

    // assign flag_x_bu        = (~y_left & ~y_signed & y_right) | (~y_left & y_signed& ~y_right);         // 001, 010
    // assign flag_2x_bu       = (~y_left & y_signed & y_right);                                           // 011
    // assign flag_neg_2x_bu   = (y_left & ~y_signed & ~y_right) ;                                         // 100
    // assign flag_neg_x_bu    = (y_left & ~y_signed & y_right) | (y_left &  y_signed & ~y_right);         // 101, 110
    // assign flag_zero        = (y_left & y_signed & y_right) | (~y_left & ~y_signed & ~y_right);         // 000, 111

    assign _x_bu        = {{32{x[31] & mul_signed}}, x};
    assign _2x_bu       = {_x_bu, 1'b0};
    assign _neg_x_bu    = ~_x_bu + 1'b1;
    assign _neg_2x_bu   = ~_2x_bu + 1'b1; 

    genvar i;
    generate
        for(i = 0; i < 33; i = i + 2)begin:gen
            booth booth_gen (
                {y_left[i],y_signed[i],y_right[i]},
                _x_bu,
                _2x_bu,
                _neg_2x_bu,
                _neg_x_bu,
                P[(i>>1)]
            );
       end
    endgenerate



    wire [63:0] level_1 [11:0];
    Adder adder1_1 (
        .a({P[15], 30'b0}),
        .b({P[14], 28'b0}),
        .c({P[13], 26'b0}),
        .carry(level_1[0]),
        .sum(level_1[1])
    );
    Adder adder1_2 (
        .a({P[12], 24'b0}),
        .b({P[11], 22'b0}),
        .c({P[10], 20'b0}),
        .carry(level_1[2]),
        .sum(level_1[3])
    );
    Adder adder1_3 (
        .a({P[ 9], 18'b0}),
        .b({P[ 8], 16'b0}),
        .c({P[ 7], 14'b0}),
        .carry(level_1[4]),
        .sum(level_1[5])
    );
    Adder adder1_4 (
        .a({P[ 6], 12'b0}),
        .b({P[ 5], 10'b0}),
        .c({P[ 4],  8'b0}),
        .carry(level_1[6]),
        .sum(level_1[7])
    );
    Adder adder1_5 (
        .a({P[ 3],  6'b0}),
        .b({P[ 2],  4'b0}),
        .c({P[ 1],  2'b0}),
        .carry(level_1[8]),
        .sum(level_1[9])
    );
    assign level_1[10] = P[0];
    assign level_1[11] = {P[16], 32'b0};
//-----------------------------------------Level 2--------------------------------------------- 
    wire [63:0] level_2 [7:0];
    Adder adder2_1 (
        .a(level_1[0]),
        .b(level_1[1]),
        .c(level_1[2]),
        .carry(level_2[0]),
        .sum(level_2[1])
    );
    Adder adder2_2 (
        .a(level_1[3]),
        .b(level_1[4]),
        .c(level_1[5]),
        .carry(level_2[2]),
        .sum(level_2[3])
    );
    Adder adder2_3 (
        .a(level_1[6]),
        .b(level_1[7]),
        .c(level_1[8]),
        .carry(level_2[4]),
        .sum(level_2[5])
    );
    Adder adder2_4 (
        .a(level_1[9]),
        .b(level_1[10]),
        .c(level_1[11]),
        .carry(level_2[6]),
        .sum(level_2[7])
    );
//-----------------------------------------Level 3--------------------------------------------- 
    wire [63:0] level_3 [5:0];
    Adder adder3_1 (
        .a(level_2[0]),
        .b(level_2[1]),
        .c(level_2[2]),
        .carry(level_3[0]),
        .sum(level_3[1])
    );
    Adder adder3_2 (
        .a(level_2[3]),
        .b(level_2[4]),
        .c(level_2[5]),
        .carry(level_3[2]),
        .sum(level_3[3])
    );
    assign level_3[4] = level_2[6];
    assign level_3[5] = level_2[7];
//-----------------------------------------Level 4--------------------------------------------- 
    wire [63:0] level_4 [3:0];
    Adder adder4_1 (
        .a(level_3[0]),
        .b(level_3[1]),
        .c(level_3[2]),
        .carry(level_4[0]),
        .sum(level_4[1])
    );
    Adder adder4_2 (
        .a(level_3[3]),
        .b(level_3[4]),
        .c(level_3[5]),
        .carry(level_4[2]),
        .sum(level_4[3])
    );
//-----------------------------------------Level 5--------------------------------------------- 
    wire [63:0] level_5 [2:0];
    Adder adder5_1 (
        .a(level_4[0]),
        .b(level_4[1]),
        .c(level_4[2]),
        .carry(level_5[0]),
        .sum(level_5[1])
    );
    assign level_5[2] = level_4[3]; 
//-----------------------------------------Level 6--------------------------------------------- 
    wire [63:0] level_6 [1:0];
    Adder adder6_1 (
        .a(level_5[0]),
        .b(level_5[1]),
        .c(level_5[2]),
        .carry(level_6[0]),
        .sum(level_6[1])
    );
    assign result = (level_6[0] + level_6[1]) & {64{resetn}};


    
endmodule