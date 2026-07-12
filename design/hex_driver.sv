// Adapted from module provided for ECE 385 at the University of Illinois Urbana Champaign
`timescale 1ns / 1ps

module hex_driver (
    input   logic           clk,
    input   logic           reset,

    input   logic   [3:0]   in[8],

    output  logic   [7:0]   hex_seg,
    output  logic   [7:0]   hex_grid
);
    
    module nibble_to_hex(
        input   logic   [3:0]   nibble,
        output  logic   [7:0]   hex_
    );
        always_comb begin
        case(nibble)
            4'b0000 : hex_ = 8'b00111111; // '0'
            4'b0001 : hex_ = 8'b00000110; // '1'
            4'b0010 : hex_ = 8'b01011011; // '2'
            4'b0011 : hex_ = 8'b01001111; // '3'
            4'b0100 : hex_ = 8'b01100110; // '4'
            4'b0101 : hex_ = 8'b01101101; // '5'
            4'b0110 : hex_ = 8'b01111101; // '6'
            4'b0111 : hex_ = 8'b00000111; // '7'
            4'b1000 : hex_ = 8'b01111111; // '8'
            4'b1001 : hex_ = 8'b01101111; // '9'
            4'b1010 : hex_ = 8'b01110111; // 'A'
            4'b1011 : hex_ = 8'b01111100; // 'b'
            4'b1100 : hex_ = 8'b00111001; // 'C'
            4'b1101 : hex_ = 8'b01011110; // 'd'
            4'b1110 : hex_ = 8'b01111001; // 'E'
            4'b1111 : hex_ = 8'b01110001; // 'F'
        endcase
        end
    endmodule

    logic [7:0] hex [8];

    genvar i;
    generate
        for(i = 0; i < 8; i++) begin
            nibble_to_hex nibble_to_hex_(
                .nibble(in[i]),
                .hex_(hex[i])
            );
        end
    endgenerate

    logic [17:0] counter;

    always_ff @( posedge clk ) begin
        if (reset) begin
            counter <= '0;
        end else begin
            counter <= counter + 1;
        end
    end

    always_comb begin
        if (reset) begin
            hex_grid = '1;
            hex_seg = '1;
        end else begin
            case (counter [17:15])
            3'b000: begin
                hex_seg = ~hex[0];
                hex_grid = 8'b11111110;
            end
            3'b001: begin
                hex_seg = ~hex[1];
                hex_grid = 8'b11111101;
            end
            2'b10: begin
                hex_seg = ~hex[2];
                hex_grid = 8'b11111011;
            end
            3'b011: begin
                hex_seg = ~hex[3];
                hex_grid = 8'b11110111;
            end
            3'b100: begin
                hex_seg = ~hex[4];
                hex_grid = 8'b11101111;
            end
            3'b101: begin
                hex_seg = ~hex[5];
                hex_grid = 8'b11011111;
            end
            3'b110: begin
                hex_seg = ~hex[6];
                hex_grid = 8'b10111111;
            end
            3'b111: begin
                hex_seg = ~hex[7];
                hex_grid = 8'b01111111;
            end
            endcase
        end
    end

endmodule
