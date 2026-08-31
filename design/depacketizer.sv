`timescale 1ns / 1ps
module depacketizer(
    input logic clk, reset,

    input logic [7:0] sink_data,
    input logic sink_valid,
                sink_last,
    output logic sink_ready,

    output logic [7:0] source_data,
    output logic source_valid,
                source_last,
    input logic source_ready
);



localparam [4:0] IP_HEADER_LEN_BYTES = 20; // minimum size (no options)
localparam [4:0] UDP_HEADER_LEN_BYTES = 8;

localparam [3:0] IP_VERSION = 4;
localparam [3:0] IP_HEADER_LEN = IP_HEADER_LEN_BYTES/4; 
localparam [7:0] IP_PROTOCOL = 17; //UDP

localparam [31:0] THIS_IP = 32'hA9_FE_50_0B; //169.254.80.11
localparam [31:0] OTHER_IP = 32'hA9_FE_50_0A; //169.254.80.10
localparam [15:0] THIS_UDP_PORT = 5000;
localparam [15:0] OTHER_UDP_PORT = 5000;

logic [15:0] byte_counter, byte_counter_n;

logic [15:0] payload_len, payload_len_n;

logic [15:0] checksum_calc, checksum_calc_n;
logic [7:0] prev_data, prev_data_n;
/*
    The ipv4 header checksum is redundant because of the ethernet header.
    I'm verifying it for my own enrichment or whatever.
*/


typedef enum logic [1:0] {
    s_chew_header,
    s_pass_payload,
    s_trash_packet
} state_t;

state_t state, state_n;

always_ff @(posedge clk) begin
    if(reset) begin
        state <= s_chew_header;
        byte_counter <= 0;

        checksum_calc <= 0;
        prev_data <= 0;

        payload_len <= 0;
    end else begin
        state <= state_n;
        byte_counter <= byte_counter_n;

        checksum_calc <= checksum_calc_n;
        prev_data <= prev_data_n;

        payload_len <= payload_len_n;
    end
end



always_comb begin
    automatic logic check_byte = 1;
    automatic logic [7:0] expected_byte;

    automatic logic [16:0] checksum_calc_temp;

    state_n = state;
    byte_counter_n = byte_counter;

    sink_ready = 0;
    source_data = 0;
    source_valid = 0;
    source_last = 0;

    checksum_calc_n = checksum_calc;
    prev_data_n = prev_data;

    payload_len_n = payload_len;
    
    case(state)
        s_chew_header: begin
            sink_ready = 1;

            if(sink_valid && sink_last) begin
                byte_counter_n = 0;
            end if(sink_valid && ~sink_last) begin
                // Header checksum calculation
                if(byte_counter < 20) begin
                    if(~byte_counter[0]) begin
                        if(byte_counter == 0) checksum_calc_n = 0;
                        prev_data_n = sink_data;
                    end else begin
                        checksum_calc_temp = {1'b0, checksum_calc} + {1'b0, prev_data, sink_data};
                        checksum_calc_n = checksum_calc_temp[15:0] + {15'b0, checksum_calc_temp[16]};
                    end
                end

                case(byte_counter) 
                    // IP Header
                    0: expected_byte = {IP_VERSION, IP_HEADER_LEN};
                    1: check_byte = 0; // DSCP, ECN
                    2, 3: check_byte = 0; // Total length
                    4, 5: check_byte = 0; // ID
                    6: expected_byte = {1'b0, sink_data[6], 6'b0}; // Flags & offset
                    7: expected_byte = 8'h00; // Fragment offset
                    8: check_byte = 0; // TTL
                    9: expected_byte = IP_PROTOCOL;
                    10, 11: check_byte = 0; // IP header checksum
                    12: expected_byte = OTHER_IP[31:24];
                    13: expected_byte = OTHER_IP[23:16];
                    14: expected_byte = OTHER_IP[15:8];
                    15: expected_byte = OTHER_IP[7:0];
                    16: expected_byte = THIS_IP[31:24];
                    17: expected_byte = THIS_IP[23:16];
                    18: expected_byte = THIS_IP[15:8];
                    19: expected_byte = THIS_IP[7:0];

                    // UDP Header
                    20: expected_byte = OTHER_UDP_PORT[15:8];
                    21: expected_byte = OTHER_UDP_PORT[7:0];
                    22: expected_byte = THIS_UDP_PORT[15:8];
                    23: expected_byte = THIS_UDP_PORT[7:0];
                    24, 25: check_byte = 0; // Length
                    26, 27: check_byte = 0; // UDP checksum
                endcase

                case(byte_counter)
                    24: payload_len_n[15:8] = sink_data;
                    25: payload_len_n = {payload_len[15:8], sink_data} - UDP_HEADER_LEN_BYTES;
                endcase


                if(check_byte && expected_byte != sink_data) begin
                    state_n = s_trash_packet;
                end else if(byte_counter == IP_HEADER_LEN_BYTES + UDP_HEADER_LEN_BYTES-1) begin
                    if(checksum_calc == 16'hFFFF) begin
                        state_n = s_pass_payload;
                        byte_counter_n = 0;
                    end else
                        state_n = s_trash_packet;
                end else begin
                    byte_counter_n = byte_counter + 1;
                end
            end
        end

        s_pass_payload: begin
            sink_ready = source_ready;
            source_valid = sink_valid;
            source_data = sink_data;
            source_last = sink_last || (byte_counter == payload_len-1);

            if(sink_valid && source_ready) begin
                if(sink_last) begin
                    state_n = s_chew_header;
                    byte_counter_n = 0;
                end else if(byte_counter == payload_len-1) begin
                    state_n = s_trash_packet;
                end else
                byte_counter_n = byte_counter + 1;
            end
        end

        s_trash_packet: begin
            sink_ready = 1;
            if(sink_valid && sink_last) begin
                state_n = s_chew_header;
                byte_counter_n = 0;
            end      
        end
    endcase
end

endmodule
