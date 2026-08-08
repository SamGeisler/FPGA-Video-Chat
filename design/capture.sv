module capture (
    input pclk,
          href,
          vsync,
    input [7:0] data,
    input reset,

    output logic [16:0] br_addra,
    output logic [15:0] br_dina,
    output logic [1:0] br_wea,
    output logic br_ena
);

typedef enum logic [3:0] {
    s_reset,
    s_vsync1, // wait for vsync to go high
    s_vsync2, // wait for vsync to go low
    s_read_b1,
    s_read_b2
} state_t;

state_t state;

//Downsampling to 320x240
localparam [9:0] STREAM_WIDTH = 640;
localparam [9:0] STREAM_HEIGHT = 480;

logic [9:0] h_count, v_count;

logic for_240p;
assign for_240p = ~h_count[0] && ~v_count[0];

logic [16:0] pixel_num;
assign pixel_num = 320*(v_count[9:1]) + h_count[9:1];


always_ff @(posedge pclk or posedge reset) begin
    if(reset) begin
        state <= s_reset;
        h_count <= 0;
        v_count <= 0;

        br_addra <= 0;
        br_dina <= 0;
        br_wea <= 0;
        br_ena <= 0;
    end else begin
        br_wea <= 2'b00;
        br_ena <= 0;

        case (state)
            s_reset: begin
                state <= s_vsync1;
                h_count <= 0;
                v_count <= 0;
            end

            s_vsync1: begin
                if(vsync)
                    state <= s_vsync2;
            end

            s_vsync2: begin
                if(~vsync)
                    state <= s_read_b1;
            end

            s_read_b1: begin
                if(href) begin
                    state <= s_read_b2;
                    if(for_240p)
                        br_dina[15:8] <= data; 
                end
            end

            s_read_b2: begin
                if(href) begin
                    if(for_240p) begin
                        br_addra <= pixel_num;
                        br_dina[7:0] <= data;
                        br_wea <= 2'b11;
                        br_ena <= 1;
                    end

                    state <= s_read_b1;
                        
                    if(h_count == STREAM_WIDTH-1) begin
                        h_count <= 0;
                        if(v_count == STREAM_HEIGHT-1) begin
                            v_count <= 0;
                            state <= s_reset;
                        end else begin
                            v_count <= v_count+1;
                        end
                    end else begin
                        h_count <= h_count + 1;
                    end
                end
            end
        endcase
    end
end
endmodule
