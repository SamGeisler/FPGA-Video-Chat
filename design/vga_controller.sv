module vga_controller (
    input logic clk, reset,
    output logic hsync, vsync,

    output logic [16:0] br_addrb, 
    input logic [15:0] br_doutb,
    output logic br_enb,

    output logic [3:0] R, G, B
);

logic active;

// Last cycle for each region
localparam [9:0] HDISP = 639;  
localparam [9:0] HFRONT = 655; 
localparam [9:0] HPULSE = 751; 
localparam [9:0] HBACK = 799;  

localparam [9:0] VDISP = 479;  
localparam [9:0] VFRONT = 489; 
localparam [9:0] VPULSE = 491; 
localparam [9:0] VBACK = 520;  

logic [9:0] hcount;
logic [9:0] vcount;

logic hsync_raw;
logic vsync_raw;
logic active_raw;

logic [8:0] pixel_x;
logic [8:0] pixel_y;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        hcount <= 0;
        vcount <= 0;
    end else begin
        if (hcount == HBACK) begin
            hcount <= 0;
            if (vcount == VBACK) begin
                vcount <= 0;
            end else begin
                vcount <= vcount + 1;
            end
        end else begin
            hcount <= hcount + 1;
        end
    end
end

assign hsync_raw  = ~(hcount > HFRONT && hcount <= HPULSE);
assign vsync_raw  = ~(vcount > VFRONT && vcount <= VPULSE);
assign active_raw = (hcount <= HDISP) && (vcount <= VDISP);

assign pixel_x = hcount[9:1];
assign pixel_y = vcount[9:1];

assign br_addrb = active_raw ? (pixel_y * 17'd320 + pixel_x) : 17'd0;
assign br_enb   = 1'b1;

// Match BRAM latency
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        hsync  <= 1'b1;
        vsync  <= 1'b1;
        active <= 1'b0;
    end else begin
        hsync  <= hsync_raw;
        vsync  <= vsync_raw;
        active <= active_raw;
    end
end

always_comb begin
    if (active) begin
        R = br_doutb[11:8];
        G = br_doutb[7:4];
        B = br_doutb[3:0];
    end else begin
        R = 4'h0;
        G = 4'h0;
        B = 4'h0;
    end
end

endmodule
