`timescale 1ns / 1ps

module color_map(
    input active,
    input [9:0] drawX, drawY,

    output logic [16:0] br_addrb, 
    input [15:0] br_doutb,
    output logic br_enb,

    output logic [3:0] R, 
    output logic [3:0] G,
    output logic [3:0] B
);

logic [16:0] pixel_num;

//Convert 240p stored data to 480p video stream
assign pixel_num = (   ({drawY[9:1],6'b0})*3'd5   +    {6'b0, drawX[9:1]}  ); // drawY * 320 + drawX

always_comb begin
    br_addrb = 0;
    br_enb = 0;
    R = 0;
    G = 0;
    B = 0;

    if(active) begin
        br_addrb = pixel_num;
        br_enb = 1;
        R = br_doutb[11:8];
        G = br_doutb[7:4];
        B = br_doutb[3:0];
    end
end

endmodule
