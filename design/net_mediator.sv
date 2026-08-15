`timescale 1ns / 1ps
module net_mediator(
    input logic clk, reset,

    output logic sink_last,
                 sink_valid,
    input logic sink_ready,
    output logic [7:0] sink_data,
    output logic [15:0] sink_eth_type,

    input logic source_last,
                source_valid,
    output logic source_ready,

    input logic [7:0] source_data,
    input logic [15:0] source_eth_type,

    output logic arp_cs,
                 ip_cs,

    output logic m_sink_last,
                 m_sink_valid,
    input logic m_sink_ready,
    output logic [7:0] m_sink_data,
    output logic [15:0] m_sink_eth_type,

    input logic m_source_last,
    output logic m_source_valid,
                 m_source_ready,

    input logic [7:0] m_source_data,
    input logic [15:0] m_source_eth_type
);

localparam [15:0] ARP_ETH_TYPE = 16'h0806;
localparam [15:0] IPv4_ETH_TYPE = 16'h0800;

typedef enum logic [1:0] {
    s_await_b0,
    s_await_b1,
    s_await_remaining,
    s_chew
} state_t;

state_t state, state_n;

logic arp_cs_n, ip_cs_n;

logic source_valid_latch;
logic [7:0] source_data_latch;

always_ff @(posedge clk) begin
    if(reset) begin
        state <= s_await_b0;
        source_valid_latch <= 0;
        source_data_latch <= 0;
        arp_cs <= 0;
        ip_cs <= 0;
    end else begin
        state <= state_n;
        source_valid_latch <= source_valid;
        source_data_latch <= source_data;
        arp_cs <= arp_cs_n;
        ip_cs <= ip_cs_n;
    end
end

always_comb begin
    state_n = state;

    source_ready = 0;
    m_source_ready = 0;
    m_source_valid = 0;

    arp_cs_n = arp_cs;
    ip_cs_n = ip_cs;

    case(state) 
        s_await_b0: begin
            source_ready = 1;
            if(source_valid) begin
                state_n = s_await_b1;
                if(source_eth_type == ARP_ETH_TYPE)
                    arp_cs_n = 1;
                else if(source_eth_type == IPv4_ETH_TYPE)
                    ip_cs_n = 1;
                else 
                    state_n = s_chew;
            end
            
            m_source_valid = 0;
        end

        s_await_b1: begin
            source_ready = 0;

            m_source_ready = 1;
            m_source_valid = source_valid_latch;

            if(source_valid)
                state_n = s_await_remaining;
        end

        s_await_remaining: begin
            source_ready = 1;

            m_source_valid = source_valid;
            m_source_ready = 0;
        end

        s_chew: begin
            
        end

        default: ;
    endcase
end

endmodule
