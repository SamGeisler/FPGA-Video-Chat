module vga_controller (
    input clk, reset,
    output hsync, vsync, active,
    output [9:0] pixel_x, pixel_y
);

logic [9:0] v_count, h_count;

//Last cycle for each region
localparam HDISP = 639;  // 640
localparam HFRONT = 655; // 640 + 16
localparam HPULSE = 751; // 640 + 16 + 96
localparam HBACK = 799;  // 640 + 16 + 96 + 48

localparam VDISP = 479;  // 480
localparam VFRONT = 489; // 480 + 10
localparam VPULSE = 491; // 480 + 10 + 2
localparam VBACK = 520;  // 480 + 10 + 2 + 29 (compensates for 25 Mhz clock)

assign hsync = (h_count <= HFRONT) || (h_count > HPULSE);
assign vsync = (v_count <= VFRONT) || (v_count > VPULSE);
assign pixel_x = (h_count <= HDISP) ? h_count : 0;
assign pixel_y = (v_count <= VDISP) ? v_count : 0;
assign active = (h_count <= HDISP) && (v_count <= VDISP);

always_ff @(posedge clk or posedge reset) begin
    if(reset) begin
        v_count <= 0;
        h_count <= 0;
    end else begin
        if(h_count == HBACK) begin
            h_count <= 0;
            if(v_count == VBACK)
                v_count <= 0;
            else
                v_count <= v_count + 1;
        end else begin
            h_count <= h_count + 1;
        end
    end
end

endmodule