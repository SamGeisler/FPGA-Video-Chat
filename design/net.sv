`timescale 1ns / 1ps

module net(
    input clk, reset,

    input           rmii_clocks_ref_clk,
    input           rmii_crs_dv,
    output          rmii_mdc,
    inout           rmii_mdio,
    input     [1:0] rmii_rx_data,
    output     [1:0] rmii_tx_data,
    output           rmii_tx_en
);

localparam [15:0] ARP_ETH_TYPE = 16'h0806;
localparam [15:0] IPV4_ETH_TYPE = 16'h0800;

logic [47:0] arp_reply_target, arp_resolved_addr;
logic arp_resolved_addr_valid, arp_replying;

//liteeth module
logic [7:0] mac_source_data, mac_sink_data;
logic mac_source_ready, mac_source_valid, mac_source_last, mac_sink_ready, mac_sink_valid, mac_sink_last;
logic [15:0] mac_sink_ethernet_type, mac_source_ethernet_type;

//Network layer modules
logic [7:0] arp_source_data, arp_sink_data;
logic arp_source_ready, arp_source_valid, arp_source_last, arp_sink_ready, arp_sink_valid, arp_sink_last;

logic [7:0] ip_source_data, ip_sink_data;
logic ip_source_ready, ip_source_valid, ip_source_last, ip_sink_ready, ip_sink_valid, ip_sink_last;
logic packetizer_start_packet;
logic [15:0] packetizer_data_len;


//Payload data processing modules
logic [7:0] trans_source_data;
logic trans_source_ready, trans_source_valid, trans_source_last;

logic [7:0] recv_sink_data;
logic recv_sink_ready, recv_sink_valid, recv_sink_last;


typedef enum logic [1:0] {
    s_transmit_none,
    s_transmit_arp,
    s_transmit_ip
} state_t;

state_t transmit_state;


always_ff @(posedge clk) begin
    if(reset) begin
        transmit_state <= s_transmit_none;
    end else begin
        case(transmit_state)
            s_transmit_none: begin
                if(arp_source_valid)
                    transmit_state <= s_transmit_arp;
                else if(ip_source_valid && arp_resolved_addr_valid == 1)
                    transmit_state <= s_transmit_ip;
            end
            s_transmit_arp: begin
                if(arp_source_last && arp_source_valid && mac_sink_ready)
                    transmit_state <= s_transmit_none;
            end
            s_transmit_ip: begin
                if(ip_source_last && ip_source_valid && mac_sink_ready)
                    transmit_state <= s_transmit_none;
            end
        endcase 
    end
end


logic mac_source_cs_arp, mac_source_cs_ip;

assign mac_source_cs_arp = mac_source_valid && mac_source_ethernet_type == ARP_ETH_TYPE;
assign mac_source_cs_ip = mac_source_valid && mac_source_ethernet_type == IPV4_ETH_TYPE;

//liteeth source multiplexer
always_comb begin
    if(mac_source_cs_arp) begin
        arp_sink_data = mac_source_data;
        arp_sink_last = mac_source_last;
        arp_sink_valid = mac_source_valid;
        mac_source_ready = arp_sink_ready;

        ip_sink_data = 8'b0;
        ip_sink_last = 1'b0;
        ip_sink_valid = 1'b0;

    end else if(mac_source_cs_ip) begin
        ip_sink_data = mac_source_data;
        ip_sink_last = mac_source_last;
        ip_sink_valid = mac_source_valid;
        mac_source_ready = ip_sink_ready;

        arp_sink_data = 8'b0;
        arp_sink_last = 1'b0;
        arp_sink_valid = 1'b0;

    end else begin
        arp_sink_data = 8'b0;
        arp_sink_last = 1'b0;
        arp_sink_valid = 1'b0;

        ip_sink_data = 8'b0;
        ip_sink_last = 1'b0;
        ip_sink_valid = 1'b0;

        mac_source_ready = 1'b1; // If unhandled ethernet type, chew the frame
    end
end

//liteeth sink multiplexer
always_comb begin
    case(transmit_state)
        default: begin
            mac_sink_data = 8'b0;
            mac_sink_last = 1'b0;
            mac_sink_valid = 1'b0;
            mac_sink_ethernet_type = 16'b0;
            arp_source_ready = 1'b0;
            ip_source_ready = 1'b0;
            
        end

        s_transmit_arp: begin
            mac_sink_data = arp_source_data;
            mac_sink_last = arp_source_last;
            mac_sink_valid = arp_source_valid;
            mac_sink_ethernet_type = ARP_ETH_TYPE;
            arp_source_ready = mac_sink_ready;
            ip_source_ready = 1'b0;
        end

        s_transmit_ip: begin
            mac_sink_data = ip_source_data;
            mac_sink_last = ip_source_last;
            mac_sink_valid = ip_source_valid; 
            mac_sink_ethernet_type = IPV4_ETH_TYPE;
            arp_source_ready = 1'b0;
            ip_source_ready = mac_sink_ready;
        end
    endcase
end

logic [47:0] video_sink_target_mac;
always_comb begin
    case (transmit_state)
    s_transmit_ip:
        video_sink_target_mac = arp_resolved_addr;
    s_transmit_arp:
        video_sink_target_mac = arp_replying ? arp_reply_target : 48'hFF_FF_FF_FF_FF_FF;
    default:
        video_sink_target_mac = 48'hFF_FF_FF_FF_FF_FF;
    endcase
end

liteeth_core liteeth_core_i(
    .sys_clock(clk), .sys_reset(reset),

    .rmii_clocks_ref_clk, .rmii_crs_dv, .rmii_mdc, .rmii_mdio, .rmii_rst_n(), .rmii_rx_data, .rmii_tx_data, .rmii_tx_en, 

    .video_sink_data(mac_sink_data), .video_sink_last(mac_sink_last), .video_sink_valid(mac_sink_valid), 
    .video_sink_ready(mac_sink_ready), .video_sink_ethernet_type(mac_sink_ethernet_type), .video_sink_last_be(1'b1), 
    .video_sink_target_mac,

    .video_source_data(mac_source_data), .video_source_error(), .video_source_last(mac_source_last), 
    .video_source_ready(mac_source_ready), .video_source_valid(mac_source_valid), .video_source_last_be(), 
    .video_source_sender_mac(), .video_source_target_mac(), .video_source_ethernet_type(mac_source_ethernet_type)
);

arp_engine arp_engine_i(
    .clk, .reset,

    .sink_data(arp_sink_data), .sink_last(arp_sink_last), .sink_ready(arp_sink_ready),
    .sink_valid(arp_sink_valid),

    .source_data(arp_source_data), .source_last(arp_source_last),
    .source_ready(arp_source_ready), .source_valid(arp_source_valid),

    .resolved_addr(arp_resolved_addr), .reply_target(arp_reply_target),
    .resolved_addr_valid(arp_resolved_addr_valid), .replying(arp_replying)
);

packetizer packetizer_i(
    .clk, .reset,

    .source_data(ip_source_data), .source_last(ip_source_last),
    .source_ready(ip_source_ready), .source_valid(ip_source_valid),

    .sink_data(trans_source_data), .sink_last(trans_source_last),
    .sink_ready(trans_source_ready), .sink_valid(trans_source_valid),

    .start_packet(packetizer_start_packet), .data_len(packetizer_data_len)
);

transmit transmit_i(
    .clk, .reset,

    .source_data(trans_source_data), .source_last(trans_source_last),
    .source_ready(trans_source_ready), .source_valid(trans_source_valid),

    .start_packet(packetizer_start_packet), .data_len(packetizer_data_len)
);

depacketizer depacketizer_i(
    .clk, .reset,

    .sink_data(ip_sink_data), .sink_last(ip_sink_last),
    .sink_ready(ip_sink_ready), .sink_valid(ip_sink_valid),

    .source_data(recv_sink_data), .source_last(recv_sink_last),
    .source_ready(recv_sink_ready), .source_valid(recv_sink_valid)
);

receive receive_i(
    .clk, .reset,

    .sink_data(recv_sink_data), .sink_last(recv_sink_last),
    .sink_ready(recv_sink_ready), .sink_valid(recv_sink_valid)
);


endmodule
