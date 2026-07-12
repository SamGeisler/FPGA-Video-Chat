`timescale 1ns / 1ps

module receive(
    input sys_clk, reset,

    input [7:0] source_data,
    input source_last, source_valid,
    output source_ready,

    output logic [16:0] buff_addr,
    output logic [15:0] buff_din,
    output logic buff_en,
    output logic [1:0] buff_we
);

localparam SWIDTH = 320;
localparam SHEIGHT = 240;

localparam NUM_WORDS = SWIDTH * SHEIGHT;
localparam PACKETS_PER_FRAME = 128;
localparam [16:0] WORDS_PER_PACKET = NUM_WORDS / PACKETS_PER_FRAME;//packets with frame headers are larger

typedef enum logic [4:0] {
    s_reset,
    s_num_lb,
    s_num_hb,
    s_data_lb,
    s_data_hb
} state_t;

state_t state, state_n;


logic ready;
assign source_ready = ready;

logic [15:0] seq_num, seq_num_n;
logic [16:0] word_num, word_num_n;


always_ff @(posedge reset or posedge sys_clk) begin
    if(reset) begin
        state <= s_reset;
        seq_num <= 0;
        word_num <= 0;
    end else begin
        state <= state_n;
        seq_num <= seq_num_n;
        word_num <= word_num_n;
    end
end

always_comb begin
    state_n = state;
    seq_num_n = seq_num;
    word_num_n = word_num;
    ready = 0;
    buff_addr = 0;
    buff_din = 0;
    buff_we = 0;
    buff_en = 0;

    case(state)
        s_reset: begin
            state_n = s_num_lb;
        end
        s_num_lb: begin
            ready = 1;
            if(source_valid) begin
                seq_num_n = {seq_num[15:8], source_data};
                state_n = s_num_hb;
            end
        end
        s_num_hb: begin
            ready = 1;
            if(source_valid) begin
                seq_num_n = {source_data, seq_num[7:0]};
                state_n = s_data_lb;
            end
        end
        s_data_lb: begin
            ready = 1;
            if(source_valid) begin
                state_n = s_data_hb;
                buff_addr = seq_num * WORDS_PER_PACKET + word_num;
                buff_en = 1;
                buff_din = {8'b0, source_data[7:0]};
                buff_we = 2'b01;
            end
        end
        s_data_hb: begin
            ready = 1;
            if(source_valid) begin
                buff_addr = seq_num * WORDS_PER_PACKET + word_num;
                buff_en = 1;
                buff_din = {source_data[7:0], 8'b0};
                buff_we = 2'b10;

                if(source_last || word_num == WORDS_PER_PACKET - 1) begin
                    state_n = s_num_lb;
                    word_num_n = 0;
                end else begin 
                    state_n = s_data_lb;
                    word_num_n = word_num + 1;
                end
            end
        end
    endcase
end

endmodule
