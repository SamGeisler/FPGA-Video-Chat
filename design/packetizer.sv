`timescale 1ns / 1ps
module packetizer(
    input logic clk, reset,

    input logic [7:0] sink_data,
    input logic sink_valid,
                sink_last,
    output logic sink_ready,

    input logic [7:0] source_data,
    input logic source_valid,
                source_last,
    output logic source_ready
);

endmodule
