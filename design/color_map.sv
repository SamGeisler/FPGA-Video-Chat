module color_map(
    input logic clk_25, clk_125,
    input logic active,
    input [9:0] drawX, drawY,

    output logic [16:0] br_addrb, 
    input logic [11:0] br_doutb,
    output logic br_enb,

    output logic [3:0] R, 
    output logic [3:0] G,
    output logic [3:0] B
);

localparam SWIDTH = 640;
localparam SHEIGHT = 480;
localparam MEMSZ = 76800;

logic [31:0] pixel_num;
assign pixel_num = (   ({drawY[9:1],6'b0})*5   +    drawX[9:1]  );

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


/*

typedef enum logic [3:0] {
    s_0, s_1, s_2, s_3, s_4, s_5,
} state_t;

state_t state, state_n;

logic last_clk_25;

logic [3:0] R_n, G_n, B_n;

always_ff @(posedge clk_125) begin
    last_clk_25 <= clk_25;

    if(clk_25 && ~last_clk_25)
        state <= s_0;
    else 
        state <= state_n;
    
    R <= R_n;
    G <= G_n;
    B <= B_n;
end

always_comb begin
    state_n = state;
    R_n = R:
    G_n = G;
    B_n = B;




    case (state)
        s_0: begin
            state_n = s_1;
            br_addrb = 1; 
            bram_enb = 1;
        end
        s_1: begin
            state_n = s_2;
            //receive bram data
            //write bram lines
        end
        s_2: begin
            state_n = s_3;
            //receive bram data
        end
        s_3: begin
            state_n = s_4;
        end
        s_4: begin
            state_n = s_0;
        end
    endcase

end
*/

endmodule