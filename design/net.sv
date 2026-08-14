`timescale 1ns / 1ps

module net(
    input sys_clk, reset,

    input           rmii_clocks_ref_clk,
    input           rmii_crs_dv,
    output          rmii_mdc,
    inout           rmii_mdio,
    input     [1:0] rmii_rx_data,
    output     [1:0] rmii_tx_data,
    output           rmii_tx_en,

    output test_successful
);

logic [15:0] video_udp_port;
assign video_udp_port = 16'd5000;

localparam [47:0] expected_eth_addr = 48'he8_97_44_2a_22_2a;

logic [7:0] source_data, sink_data;
logic source_ready, sink_ready, source_last, sink_last, source_valid, sink_valid;

logic [47:0] eth_addr;
logic eth_addr_valid;

logic [47:0] sink_eth_addr;
assign sink_eth_addr = eth_addr_valid ? eth_addr : 48'hFF_FF_FF_FF_FF_FF;
logic [15:0] sink_eth_type;
assign sink_eth_type = eth_addr_valid ? 16'h0800 : 16'h0806;

liteeth_core eth_i(
    .rmii_clocks_ref_clk, .rmii_crs_dv, .rmii_mdc, .rmii_mdio, .rmii_rst_n(), .rmii_rx_data, .rmii_tx_data, .rmii_tx_en, 

    .sys_clock(sys_clk), .sys_reset(reset),

    .video_sink_data(sink_data), .video_sink_last(sink_last), .video_sink_valid(sink_valid), 
    .video_sink_ready(sink_ready), .video_sink_ethernet_type(sink_eth_type), .video_sink_last_be(1'b1), 
    .video_sink_target_mac(sink_eth_addr),

    .video_source_data(source_data), .video_source_error(), .video_source_last(source_last), 
    .video_source_ready(source_ready), .video_source_valid(source_valid), .video_source_last_be(), 
    .video_source_sender_mac(), .video_source_target_mac(), .video_source_ethernet_type()
);


arp_req ari(.clk(sys_clk), .reset, .sink_data, .sink_last, .sink_ready, .sink_valid, 
            .source_data, .source_last, .source_ready, .source_valid, .addr(eth_addr),
            .addr_valid(eth_addr_valid));

assign test_successful = eth_addr_valid && eth_addr == expected_eth_addr;

endmodule