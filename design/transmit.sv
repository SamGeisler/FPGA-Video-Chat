module transmit(
    input sys_clk, reset,

    output logic [16:0] br_addrb, 
    input [15:0] br_doutb,
    output logic br_enb,

    output [7:0] sink_data,
    input sink_ready,
    output sink_valid, sink_last
);

localparam SWIDTH = 320;
localparam SHEIGHT = 240;

localparam NUM_WORDS = SWIDTH * SHEIGHT;
localparam PACKETS_PER_FRAME = 128;
localparam WORDS_PER_PACKET = NUM_WORDS / PACKETS_PER_FRAME;//packets with frame headers are larger

localparam PACKET_DELAY_CYCLES = 100_000;

logic [31:0] config_delay_counter;
logic [15:0] packet_num, packet_num_n;
logic [15:0] word_num, word_num_n; // Word in packet
logic [15:0] word_latch, word_latch_n;
logic [31:0] packet_delay_counter, packet_delay_counter_n;

typedef enum logic [4:0] {
    s_reset,
    s_frame_header_b1,
    s_frame_header_b2,
    s_frame_header_b3, 
    s_frame_header_b4,
    s_lb,
    s_hb,
    s_packet_delay
} state_t;

state_t state, state_n;

always_ff @(posedge sys_clk or posedge reset) begin
    if(reset) begin
        state <= s_reset;
        config_delay_counter <= 0;
        word_num <= 0;
        word_latch <= 0;
        packet_delay_counter <= 0;
    end else if(config_delay_counter < 32'd10_000_000) begin
        config_delay_counter <= config_delay_counter + 1;
    end else begin
        state <= state_n;
        word_num <= word_num_n;
        packet_num <= packet_num_n;
        word_latch <= word_latch_n;
        packet_delay_counter <= packet_delay_counter_n;
    end
end

logic [7:0] data;
logic valid, last;

assign sink_data = data;
assign sink_valid = valid;
assign sink_last = last;

always_comb begin
    state_n = state;
    data = 8'b0;
    valid = 0;
    last = 0;
    word_num_n = word_num;
    packet_num_n = packet_num;
    word_latch_n = word_latch;
    packet_delay_counter_n = packet_delay_counter;

    br_addrb = 0;
    br_enb = 0;

    case(state)
        s_reset: begin
            state_n = s_frame_header_b1;
            word_num_n = 0;
            packet_num_n = 0;
        end

        s_frame_header_b1: begin
            valid = 1;
            data = packet_num[15:8];
            if(sink_ready)
                state_n = s_frame_header_b2;
        end

        s_frame_header_b2: begin
            valid = 1;
            data = packet_num[7:0];
            if(sink_ready) begin
                state_n = s_lb;
                br_addrb = {16'b0,packet_num} * WORDS_PER_PACKET + word_num;
                br_enb = 1;
            end
        end

        s_lb: begin
            valid = 1;
            data = br_doutb[7:0];
            word_latch_n = br_doutb;
            if(sink_ready)
                state_n = s_hb;
        end
        
        s_hb: begin
            valid = 1;
            data = word_latch[15:8];
            if(word_num == WORDS_PER_PACKET-1)
                last = 1;
            
            if(sink_ready) begin
                if(word_num == WORDS_PER_PACKET-1) begin
                    state_n = s_packet_delay;
                    packet_delay_counter_n = 0;
                end else begin
                    state_n = s_lb;
                    word_num_n = word_num + 1;

                    br_addrb = {16'b0,packet_num_n} * WORDS_PER_PACKET + word_num_n;
                    br_enb = 1;
                end
            end
        end

        s_packet_delay: begin
            packet_delay_counter_n = packet_delay_counter + 1;
            if(packet_delay_counter == PACKET_DELAY_CYCLES-1) begin
                if(packet_num == PACKETS_PER_FRAME-1)
                    state_n = s_reset;
                else begin
                    state_n = s_frame_header_b1;
                    word_num_n = 0;
                    packet_num_n = packet_num + 1;

                    br_addrb = {16'b0,packet_num_n} * WORDS_PER_PACKET + word_num_n;
                    br_enb = 1;
                end
            end
        end
    endcase
end

endmodule