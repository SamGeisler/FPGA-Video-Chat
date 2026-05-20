module udp_test_top(
    input sys_clk, reset,

    input           rmii_clocks_ref_clk,
    input           rmii_crs_dv,
    output          rmii_mdc,
    inout           rmii_mdio,
    input     [1:0] rmii_rx_data,
    output     [1:0] rmii_tx_data,
    output           rmii_tx_en
);

localparam WORD_COUNTER_MAX = 80;

logic [7:0] sink_data;
logic sink_ready, sink_valid, sink_last;

liteeth_core #(.VIDEO_IP_ADDR(32'hc0a80172), .VIDEO_UDP_PORT(5000)) eth_i
                  (.rmii_clocks_ref_clk, .rmii_crs_dv, .rmii_mdc, .rmii_mdio, .rmii_rst_n(),
                   .rmii_rx_data, .rmii_tx_data, .rmii_tx_en, .sys_clock(sys_clk), .sys_reset(reset),
                   .video_sink_data(sink_data), .video_sink_last(sink_last), .video_sink_valid(sink_valid), 
                   .video_sink_ready(sink_ready), .video_source_data(), .video_source_error(), 
                   .video_source_last(), .video_source_ready(0), .video_source_valid());

logic [31:0] config_delay_counter;
logic [31:0] wait_counter, wait_counter_n;
logic [31:0] word_counter, word_counter_n;


typedef enum logic [4:0] {
    s_WAIT_READY,
    s_SEND,
    s_DELAY
} state_t;

state_t state, state_n;

always_ff @(posedge sys_clk or posedge reset) begin
    if(reset) begin
        state <= s_WAIT_READY;
        config_delay_counter <= 0;
        wait_counter <= 0;
        word_counter <= 0;
    end else if(config_delay_counter < 32'd10_000_000) begin
        config_delay_counter <= config_delay_counter + 1;
    end else begin
        state <= state_n;
        wait_counter <= wait_counter_n;
        word_counter <= word_counter_n;
    end
end

always_comb begin
    state_n = state;
    sink_data = 8'b0;
    sink_valid = 0;
    sink_last = 0;
    wait_counter_n = 0;
    word_counter_n = word_counter;

    case(state)
        s_WAIT_READY: begin
            sink_valid = 1;
            sink_data  = 8'b1;
            if(sink_ready) begin
                word_counter_n = 2;
                state_n = s_SEND;
            end
        end

        s_SEND: begin
            sink_valid = 1;
            sink_data = word_counter;
            if(word_counter == WORD_COUNTER_MAX)
                sink_last = 1;

            if(sink_ready) begin
                if(word_counter >= WORD_COUNTER_MAX)
                    state_n = s_DELAY;
                else
                    word_counter_n = word_counter + 1;
            end
        end
        // s_B2: begin
        //     sink_valid = 1;
        //     sink_data  = 8'hBE;
        //     if(sink_ready)
        //         state_n = s_B3;
        // end

        // s_B3: begin
        //     sink_valid = 1;
        //     sink_data  = 8'hAD;
        //     if(sink_ready)
        //         state_n = s_B4;
        // end

        // s_B4: begin
        //     sink_valid = 1;
        //     sink_data  = 8'hDE;
        //     sink_last  = 1;
        //     if(sink_ready)
        //         state_n = s_DELAY;
        // end

        s_DELAY: begin
            wait_counter_n = wait_counter + 1;
            if(wait_counter >= 32'd100_000_000)
                state_n = s_WAIT_READY;
        end 
    endcase

end

endmodule