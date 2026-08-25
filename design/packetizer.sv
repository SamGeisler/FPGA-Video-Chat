`timescale 1ns / 1ps
module packetizer(
    input logic clk, reset,

    /* 
        Ideally, start_packet will be asserted by the sender before the actual data transmission begins
        in order for this module to begin checksum calcuation and header transmission as soon as possible.
        This value is latched, and will be interpreted as valid and referring to a new packet if it is high at
        any point after data transmission for the current packet has begun.

        Total_len is interpreted as valid (and latched) when start_packet is high.

        Checksum calculation, but not header transmission, can be performed while another packet is being transmitted.
    */
    input logic start_packet, 
    input logic [15:0] total_len,

    input logic [7:0] sink_data,
    input logic sink_valid,
                sink_last,
    output logic sink_ready,

    output logic [7:0] source_data,
    output logic source_valid,
                source_last,
    input logic source_ready
);

localparam [3:0] IP_VERSION = 4;
localparam [3:0] IP_HEADER_LEN = 5; // 20 bytes (minimum size)
localparam [15:0] IP_PACKET_ID = 0; // Assuming zero packet fragmentation (direct link). Meaningful value not required
localparam [2:0] IP_FLAGS = 3'b010; // [Reserved, Don't fragment, More Fragments] 
localparam [12:0] FRAGMENT_OFFSET = 0; // Unused
localparam [7:0] IP_PROTOCOL = 17; //UDP
localparam [15:0] CHECKSUM = ?;
localparam [31:0] IP_SRC_ADDR = 32'hA9_FE_50_0B; //169.254.80.11
localparam [31:0] IP_DEST_ADDR = 32'hA9_FE_50_0A; //169.254.80.10

typedef enum logic [2:0] {
    s_reset,
    s_idle,
    s_transmit_header,
    s_transmit_data
} state_t;

state_t state, state_n;

logic [5:0] header_byte_counter, header_byte_counter_n;


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
            if(start_packet) begin
                state_n = s_transmit_header;
                header_byte_counter_n = 0;
            end
        end

        s_transmit_header: begin
            source_valid = 1;

            case(header_byte_counter)


            endcase



            if(source_ready) begin
                

                if(header_byte_counter == HEADER_LEN-1) begin
                    state_n = s_transmit_data;
                end
                    header_byte_counter_n = header_byte_counter + 1;
            end
        end

        s_transmit_data: begin
            
        end

    endcase
end

endmodule
