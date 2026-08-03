`timescale 1ns/ 1ps

module cam_top(
    input clk_100, reset,

    //Control inputs
    input setup_btn,
    input [15:0] sw_i,

    //Seven segment displays
    output logic [7:0] hex_grid,
    output logic [7:0] hex_seg,

    //LEDs
    output debug_light,

    //Camera
    inout wire c_SDA,
    input c_PLK,
    input [7:0]c_D,
    input c_VS, c_HS,
    output logic c_SCL,
    output logic c_XLK,
    output logic c_RET, c_PWDN,

    //VGA
    output [3:0] VGA_R, VGA_G, VGA_B,
    output VGA_HS, VGA_VS,

    //Ethernet
    input           rmii_crs_dv,
    output          rmii_mdc,
    inout           rmii_mdio,
    input     [1:0] rmii_rx_data,
    output     [1:0] rmii_tx_data,
    output           rmii_tx_en,
    output           rmii_clk_in
);

//Inputs
logic setup_btn_db;

sync_debounce sdbi3 (.Clk(clk_100), .d(setup_btn), .q(setup_btn_db));

logic [31:0] selected_ip;


// Innitialization
logic init_done_tick, init_done_tick_latched;
assign init_reset = reset | ~init_done_tick_latched;

//bram signals - transmit buffer
logic [16:0] trans_addra;
logic [15:0] trans_dina;
logic trans_ena;
logic [1:0] trans_wea;

logic [16:0] trans_addrb;
logic [15:0] trans_doutb;
logic trans_enb;


//ram signals - receive buffer
logic [16:0] recv_addra;
logic [15:0] recv_dina;
logic recv_ena;
logic [1:0] recv_wea;


logic [16:0] recv_addrb;
logic [15:0] recv_doutb;
logic recv_enb;


//timing signals
logic clk_25, clk_50_internal;

//Internal vga signals
logic [9:0] VGA_drawX, VGA_drawY;
logic VGA_active;

//Camera signal assignments
assign c_RET = ~reset;
assign c_PWDN = 0;
assign c_XLK = clk_25;

// Transmit buffer: camera -> buffer -> network transmission
blk_mem_gen_0 transmit_buf(.clka(clk_100), .clkb(clk_100), .ena(trans_ena), .wea(trans_wea),
                           .addra(trans_addra), .dina(trans_dina), .douta(),
                           .enb(trans_enb), .web(1'b0),
                           .addrb(trans_addrb), .dinb(16'b0), .doutb(trans_doutb));

// Receive buffer: Network -> buffer -> VGA
blk_mem_gen_0 recv_buf(.clka(clk_100), .clkb(clk_100), .ena(recv_ena), .wea(recv_wea),
                           .addra(recv_addra), .dina(recv_dina), .douta(),
                           .enb(recv_enb), .web(1'b0),
                           .addrb(recv_addrb), .dinb(16'b0), .doutb(recv_doutb));

clk_wiz_0 clk_wiz_i(.reset(reset), .clk_in(clk_100), .clk_125(), .clk_50(clk_50_internal), .clk_25, .locked());

ODDR #(.DDR_CLK_EDGE("OPPOSITE_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) rmii_clk_forward_inst 
    (.Q(rmii_clk_in), .C(clk_50_internal), 
     .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));

vga_controller vga_i(.clk(clk_25), .reset(init_reset), .hsync(VGA_HS), .vsync(VGA_VS), .active(VGA_active), .pixel_x(VGA_drawX), .pixel_y(VGA_drawY));

color_map cmap_i(.active(VGA_active), .drawX(VGA_drawX), .drawY(VGA_drawY), .br_addrb(recv_addrb), .br_doutb(recv_doutb), .br_enb(recv_enb), .R(VGA_R), .G(VGA_G), .B(VGA_B));

net net_i(.sys_clk(clk_100), .reset(init_reset), .rmii_clocks_ref_clk(clk_50_internal), .rmii_crs_dv, .rmii_mdc, .rmii_mdio,
                     .rmii_rx_data, .rmii_tx_data, .rmii_tx_en, .send_buff_addr(trans_addrb),
                     .send_buff_dout(trans_doutb), .send_buff_en(trans_enb), .recv_buff_addr(recv_addra),
                     .recv_buff_din(recv_dina), .recv_buff_en(recv_ena), .recv_buff_we(recv_wea),
                     .ipaddr(selected_ip));

capture capture_i(.data(c_D), .clk_100, .href(c_HS), .vsync(c_VS), .pclk(c_PLK), .br_addra(trans_addra), .br_dina(trans_dina), .br_ena(trans_ena), .br_wea(trans_wea), .reset(init_reset), .debug_bit(debug_light));

logic sda_in, sda_oe;
assign c_SDA = sda_oe ? 1'b0 : 1'bz;
assign sda_in = c_SDA;

init init_i(.clk(clk_100), .reset, .sda_in, .sda_oe, .init_done_tick, .scl(c_SCL), .ipaddr(selected_ip), .done_btn(setup_btn_db), .sw_i);

always_ff @(posedge clk_100) begin
    if(reset)
        init_done_tick_latched <= 0;
    else
        if(init_done_tick)
            init_done_tick_latched <= 1;
end


// Unpack selected IP address
logic [3:0] ip_array [8];
always_comb begin
    for (int i = 0; i < 8; i++) begin
        ip_array[i] = selected_ip[31 - (i*4) -: 4]; 
    end
end

hex_driver hdA(.clk(clk_100), .reset, .in(ip_array), .hex_seg, .hex_grid);


endmodule
