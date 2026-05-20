module capture(
    input logic clk_100, reset,
    input logic [7:0] data,
    input logic href, vsync,
    input logic pclk,

    input logic capture,

    output logic [16:0] br_addra,
    output logic [15:0] br_dina,
    output logic [1:0] br_wea,
    output logic br_ena
);

localparam SWIDTH = 640;
localparam SHEIGHT = 480;
localparam MEMSZ = 76800;

logic [9:0] h_count, h_count_n, v_count, v_count_n;

logic [2:0] pclk_sync, href_sync, vsync_sync;
logic [23:0] data_sync;

always_ff @(posedge clk_100) begin
    pclk_sync <= {pclk_sync[1:0], pclk};
    href_sync <= {href_sync[1:0], href};
    vsync_sync <= {vsync_sync[1:0], vsync};
    data_sync <= {data_sync[15:8], data_sync[7:0], data};
end

logic [16:0] br_addr_latch, br_addr_latch_n;
logic [15:0] br_din_latch, br_din_latch_n;
logic [1:0] br_we_latch, br_we_latch_n;
logic br_en_latch, br_en_latch_n;

assign br_addra = br_addr_latch;
assign br_dina = br_din_latch;
assign br_wea = br_we_latch;
assign br_ena = br_en_latch;


typedef enum logic [3:0] {
    s_reset,
    s_vsync1, // wait for vsync to go high
    s_vsync2, // wait for vsync to go low
    s_wait_href,
    s_wait_rising_b1,
    s_read_b1,
    s_wait_rising_b2,
    s_read_b2,
    s_wait_href_fall,
    s_btn_released
} state_t;

state_t state, state_n;

always_ff @(posedge clk_100 or posedge reset) begin
    if(reset) begin
        state <= s_reset;
        h_count <= 0;
        v_count <= 0;

        br_addr_latch <= 0;
        br_din_latch <= 0;
        br_we_latch <= 0;
        br_en_latch <= 0;
    end else begin
        state <= state_n;
        h_count <= h_count_n;
        v_count <= v_count_n;

        br_addr_latch <= br_addr_latch_n;
        br_din_latch <= br_din_latch_n;
        br_we_latch <= br_we_latch_n;
        br_en_latch <= br_en_latch_n;
    end
end


logic [31:0] pixel_num;
assign pixel_num = (   {v_count[9:1], 6'b0}*5   +  h_count[9:1]  );

always_comb begin
    //default values
    state_n = state;
    h_count_n = h_count;
    v_count_n = v_count;

    br_addr_latch_n = 0;
    br_din_latch_n = 0;
    br_we_latch_n = 0;
    br_en_latch_n = 0;

    case (state)
        s_reset: begin
            if(1)
                state_n = s_vsync1;
        end
        s_vsync1: begin
            if(vsync_sync[2])
                state_n = s_vsync2;
        end
        s_vsync2: begin
            if(~vsync_sync[2]) begin
                v_count_n = 0;
                h_count_n = 0;
                state_n = s_wait_href;
            end
        end
        s_wait_href: begin
            if(href_sync[2])
                state_n = s_wait_rising_b1;
        end
        s_wait_rising_b1: begin
            if(~pclk_sync[2] && pclk_sync[1])
                state_n = s_read_b1;
        end
        s_read_b1: begin
            if(~h_count[0] && ~v_count[0]) begin
                br_addr_latch_n = pixel_num; 
                br_din_latch_n[15:8] = data_sync[23:16];
                br_we_latch_n = 2'b10;
                br_en_latch_n = 1;
            end

            state_n = s_wait_rising_b2;
        end
        s_wait_rising_b2: begin
            if(~pclk_sync[2] && pclk_sync[1])
                state_n = s_read_b2;
        end
        s_read_b2: begin
            if(~h_count[0] && ~v_count[0]) begin
                br_addr_latch_n = pixel_num;
                br_din_latch_n[7:0] = data_sync[23:16];
                br_we_latch_n = 2'b01;
                br_en_latch_n = 1;
            end

            if(h_count == SWIDTH-1) begin
                h_count_n = 0;
                
                if(v_count == SHEIGHT-1) begin
                    v_count_n = 0;
                    state_n = s_reset;
                end else begin
                    v_count_n = v_count + 1;
                    state_n = s_wait_href_fall;
                end
            
            end else begin
                h_count_n = h_count + 1;
                state_n = s_wait_rising_b1;
            end
        end
        s_wait_href_fall: begin
            if(~href_sync[2])
                state_n = s_wait_href;
        end

    endcase
end

endmodule