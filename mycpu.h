`ifndef mycpu
    `define mycpu

    `define IF_ID_LEN 64
    `define ID_EX_LEN 162+1


    `define CRMD 14'h0
    `define PRMD 14'h1
    `define ECFG 14'h4
    `define ESTAT 14'h5
    `define ERA 14'h6
    `define EENTRY 14'hc
    `define SAVE0  14'h30
    `define SAVE1  14'h31
    `define SAVE2  14'h32
    `define SAVE3  14'h33
    `define TICLR  14'h44
    `define ECFG  14'h4
    `define BADV  14'h7
    `define TID  14'h40
    `define TCFG  14'h41
    `define TVAL  14'h42

    `define TCFG_N 32

    
`endif
