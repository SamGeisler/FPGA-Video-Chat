`timescale 1ns / 1ps

module transmit(
    input clk, reset,

    output logic [7:0] source_data,
    output logic source_valid, source_last,
    input logic source_ready,

    output logic start_packet,
    output logic [15:0] data_len
);

endmodule
