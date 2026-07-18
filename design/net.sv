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

    input [31:0] ipaddr,

    output [16:0] send_buff_addr, 
    input [15:0] send_buff_dout,
    output send_buff_en,

    output [16:0] recv_buff_addr,
    output [15:0] recv_buff_din,
    output recv_buff_en,
    output [1:0] recv_buff_we
);

logic [7:0] source_data, sink_data;
logic source_ready, sink_ready, source_last, sink_last, source_valid, sink_valid;

logic [15:0] video_udp_port;
assign video_udp_port = 16'd5000;

liteeth_core eth_i
                  (.rmii_clocks_ref_clk, .rmii_crs_dv, .rmii_mdc, .rmii_mdio, .rmii_rst_n(),
                   .rmii_rx_data, .rmii_tx_data, .rmii_tx_en, .sys_clock(sys_clk), .sys_reset(reset),
                   .video_sink_data(sink_data), .video_sink_last(sink_last), .video_sink_valid(sink_valid), 
                   .video_sink_ready(sink_ready), .video_source_data(source_data), .video_source_error(), 
                   .video_source_last(source_last), .video_source_ready(source_ready), .video_source_valid(source_valid),
                   .video_udp_port, .video_ip_address(ipaddr));

transmit transmit_i (.sys_clk, .reset, .br_addrb(send_buff_addr), .br_doutb(send_buff_dout), 
                     .br_enb(send_buff_en), .sink_data, .sink_valid, .sink_last, .sink_ready);

receive receive_i (.sys_clk, .reset, .source_data, .source_last, .source_valid,
                   .source_ready, .buff_addr(recv_buff_addr), .buff_din(recv_buff_din),
                   .buff_en(recv_buff_en), .buff_we(recv_buff_we));

endmodule
