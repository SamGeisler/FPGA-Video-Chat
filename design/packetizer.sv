`timescale 1ns / 1ps
module packetizer(
    input logic clk, reset,

    /* 
        Ideally, start_packet will be asserted by the sender before the actual data transmission begins
        in order for this module to begin checksum calcuation and header transmission as soon as possible.
        This value is latched, and will be interpreted as valid and referring to a new packet if it is high at
        any point after PAYLOAD transmission for the current packet has begun.

        Total_len is interpreted as valid (and latched) on the rising edge of start_packet

        Checksum calculation, but not header transmission, can be performed while another packet is being transmitted.

        Only a single packet can be queued at once. If the transmitter attempts to assert start_packet for the second
        time before the first time is processed, that second time will be ignored.
    */
    input logic start_packet, 
    input logic [15:0] data_len,

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
localparam [5:0] IP_DSCP = 0; // Differentiated Services Code Point (unused)
localparam [1:0] IP_ECN = 0; // Explicit Congestion notification (unused)
localparam [15:0] IP_PACKET_ID = 0; // Assuming zero packet fragmentation (direct link). Meaningful value not required
localparam [2:0] IP_FLAGS = 3'b010; // [Reserved, Don't fragment, More Fragments] 
localparam [12:0] IP_FRAGMENT_OFFSET = 0; // Unused
localparam [7:0] IP_TTL = 4;
localparam [7:0] IP_PROTOCOL = 17; //UDP
localparam [31:0] THIS_IP = 32'hA9_FE_50_0B; //169.254.80.11
localparam [31:0] OTHER_IP = 32'hA9_FE_50_0A; //169.254.80.10

localparam [15:0] IP_HEADER_CHECKSUM_P1 = {IP_VERSION, IP_HEADER_LEN, IP_DSCP, IP_ECN};
localparam [15:0] IP_HEADER_CHECKSUM_P2 = 16'h3824;

localparam [15:0] UDP_SRC_PORT = 5000;
localparam [15:0] UDP_DEST_PORT = 5000;
localparam [15:0] UDP_CHECKSUM = 0; // Unused


typedef enum logic [2:0] {
    s_reset,
    s_idle,
    s_transmit_ip_header,
    s_transmit_udp_header,
    s_transmit_data
} state_t;

state_t state, state_n;

logic [4:0] header_byte_counter, header_byte_counter_n;


// Header checksum generation is always triggered when start_packet goes high. It will be ready by the time the transmission module needs to transmit the header

logic start_packet_latched;
logic [15:0] total_len_latched;
logic [1:0] checksum_calc_stage;

logic [15:0] running_checksum;

always_ff @(posedge clk) begin
    automatic logic [16:0] checksum_temp;

    if(reset) begin
        start_packet_latched <= 0;
        total_len_latched <= 0;

        checksum_calc_stage <= 0;
        running_checksum <= 0;
    end else begin
        if(state == s_transmit_ip_header || state == s_transmit_udp_header) begin
            if(header_byte_counter == IP_HEADER_LEN_BYTES-1) 
                start_packet_latched <= 0;
            else
                start_packet_latched <= start_packet_latched;
        end else 
            start_packet_latched <= start_packet_latched ? 1'b1 : start_packet;


        if(start_packet && ~start_packet_latched) begin
            total_len_latched <= data_len + IP_HEADER_LEN_BYTES + UDP_HEADER_LEN_BYTES;
            running_checksum <= IP_HEADER_CHECKSUM_P1;

            checksum_calc_stage <= 1;
        end else if(checksum_calc_stage == 1) begin
            checksum_temp = running_checksum + total_len_latched;
            running_checksum <= checksum_temp[15:0] + {15'b0, checksum_temp[16]};

            checksum_calc_stage <= 2;
        end else if(checksum_calc_stage == 2) begin
            checksum_temp = running_checksum + IP_HEADER_CHECKSUM_P2;
            running_checksum <= ~{checksum_temp[15:0] + {15'b0, checksum_temp[16]}};

            checksum_calc_stage <= 3;
        end
    end
end



always_ff @(posedge clk) begin
    if(reset) begin
        state <= s_reset;
        header_byte_counter <= 0;
    end else begin
        state <= state_n;
        header_byte_counter <= header_byte_counter_n;
    end
end

always_comb begin
    state_n = state;
    header_byte_counter_n = header_byte_counter;

    sink_ready = 0;
    source_data = 0;
    source_valid = 0;
    source_last = 0;

    case(state)
        s_reset:
            state_n = s_idle;

        s_idle: begin
            if(start_packet_latched) begin
                state_n = s_transmit_ip_header;
                header_byte_counter_n = 0;
            end
        end

        s_transmit_ip_header: begin
            source_valid = 1;

            case(header_byte_counter)
                0: source_data = {IP_VERSION, IP_HEADER_LEN};
                1: source_data = {IP_DSCP, IP_ECN};
                2: source_data = total_len_latched[15:8];
                3: source_data = total_len_latched[7:0];
                4: source_data = IP_PACKET_ID[15:8];
                5: source_data = IP_PACKET_ID[7:0];
                6: source_data = {IP_FLAGS, IP_FRAGMENT_OFFSET[12:8]};
                7: source_data = IP_FRAGMENT_OFFSET[7:0];
                8: source_data = IP_TTL;
                9: source_data = IP_PROTOCOL;
                10: source_data = running_checksum[15:8];
                11: source_data = running_checksum[7:0];
                12: source_data = THIS_IP[31:24];
                13: source_data = THIS_IP[23:16];
                14: source_data = THIS_IP[15:8];
                15: source_data = THIS_IP[7:0];
                16: source_data = OTHER_IP[31:24];
                17: source_data = OTHER_IP[23:16];
                18: source_data = OTHER_IP[15:8];
                19: source_data = OTHER_IP[7:0];
            endcase

            if(source_ready) begin
                if(header_byte_counter == IP_HEADER_LEN_BYTES-1) begin
                    state_n = s_transmit_udp_header;
                    header_byte_counter_n = 0;
                end else 
                    header_byte_counter_n = header_byte_counter + 1;
            end
        end

        s_transmit_udp_header: begin
            source_valid = 1;

            case(header_byte_counter)
                0: source_data = UDP_SRC_PORT[15:8];
                1: source_data = UDP_SRC_PORT[7:0];
                2: source_data = UDP_DEST_PORT[15:8];
                3: source_data = UDP_DEST_PORT[7:0];
                4: source_data = {total_len_latched - IP_HEADER_LEN_BYTES}[15:8];
                5: source_data = {total_len_latched - IP_HEADER_LEN_BYTES}[7:0];
                6: source_data = UDP_CHECKSUM[15:8];
                7: source_data = UDP_CHECKSUM[7:0];
            endcase

            if(source_ready) begin
                if(header_byte_counter == UDP_HEADER_LEN_BYTES-1) begin
                    state_n = s_transmit_data;
                end
                    header_byte_counter_n = header_byte_counter + 1;
            end
        end

        s_transmit_data: begin
            source_valid = sink_valid;
            source_data = sink_data;
            source_last = sink_last;
            sink_ready = source_ready;

            if(sink_valid && sink_last && source_ready)
                state_n = s_idle;
        end

    endcase
end


endmodule
