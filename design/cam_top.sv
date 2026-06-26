module cam_top(
    input clk_100, reset,

    //Control inputs
    input capture,
    input write_btn, setup_btn,
    input [15:0] sw_i,

    //Seven segment displays
    output logic [7:0] hex_grid,
    output logic [7:0] hex_seg,

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
    input           rmii_clocks_ref_clk,
    input           rmii_crs_dv,
    output          rmii_mdc,
    inout           rmii_mdio,
    input     [1:0] rmii_rx_data,
    output     [1:0] rmii_tx_data,
    output           rmii_tx_en,
    output           rmii_clk_in
);

//Inputs
logic capture_db, write_btn_db, setup_btn_db;

sync_debounce sdbi (.Clk(clk_100), .d(capture), .q(capture_db));
sync_debounce sdbi2 (.Clk(clk_100), .d(write_btn), .q(write_btn_db));
sync_debounce sdbi3 (.Clk(clk_100), .d(setup_btn), .q(setup_btn_db));

logic [31:0] selected_ip;


//bram signals - transmit buffer
logic [16:0] br_addra, br_addrb;
logic [11:0] br_dina, br_douta, br_doutb;
logic br_ena, br_enb;
logic [1:0] br_wea;

//ram signals - receive buffer
logic [16:0] recv_addra, recv_addrb;
logic [11:0] recv_dina, recv_doutb;
logic recv_ena, recv_enb;
logic [1:0] recv_wea;

//timing signals
logic clk_25, clk_125, clk_locked;

//Internal vga signals
logic [9:0] VGA_drawX, VGA_drawY;
logic VGA_active;

//Camera signal assignments
assign c_RET = ~reset;
assign c_PWDN = 0;
assign c_XLK = clk_25;

// Transmit buffer: camera -> buffer -> network transmission
// blk_mem_gen_0 blk_mem_i(.addra(br_addra), .clka(clk_100), .dina(br_dina),
//                         .douta(br_douta), .ena(br_ena), .wea(br_wea),
//                         .addrb(br_addrb), .clkb(clk_100), .dinb(32'b0),
//                         .doutb(br_doutb), .enb(br_enb), .web(2'b0));
dual_port_dist_ram dpdr_i(.clk(clk_100), .ena(br_ena), .enb(br_enb), .wea(br_wea),
                          .addra(br_addra), .addrb(br_addrb), .dina(br_dina),
                          .doutb(br_doutb));


// Receive buffer: Network -> buffer -> VGA
dual_port_dist_ram dpdr_i2(.clk(clk_100), .ena(recv_ena), .enb(recv_enb), .wea(recv_wea),
                          .addra(recv_addra), .addrb(recv_addrb), .dina(recv_dina),
                          .doutb(recv_doutb));

clk_wiz_0 clk_wiz_i(.reset(reset), .clk_in(clk_100), .clk_125, .clk_50(rmii_clk_in), .clk_25, .locked(clk_locked));

vga_controller vga_i(.clk(clk_25), .reset(reset), .hsync(VGA_HS), .vsync(VGA_VS), .active(VGA_active), .pixel_x(VGA_drawX), .pixel_y(VGA_drawY));

color_map cmap_i(.active(VGA_active), .drawX(VGA_drawX), .drawY(VGA_drawY), .br_addrb(recv_addrb), .br_doutb(recv_doutb), .br_enb(recv_enb), .R(VGA_R), .G(VGA_G), .B(VGA_B), .clk_25, .clk_125);

net net_i(.sys_clk(clk_100), .reset, .rmii_clocks_ref_clk, .rmii_crs_dv, .rmii_mdc, .rmii_mdio,
                     .rmii_rx_data, .rmii_tx_data, .rmii_tx_en, .send_buff_addr(br_addrb),
                     .send_buff_dout(br_doutb), .send_buff_en(br_enb), .recv_buff_addr(recv_addra),
                     .recv_buff_din(recv_dina), .recv_buff_en(recv_ena), .recv_buff_we(recv_wea),
                     .ipaddr(selected_ip));

capture capture_i(.data(c_D), .clk_100, .href(c_HS), .vsync(c_VS), .pclk(c_PLK), .capture(capture_db), .br_addra, .br_dina, .br_ena, .br_wea, .reset);


//Camera configuration
localparam REG_WRITE = 0;
localparam REG_READ = 1;
localparam r_COM7 = 8'h12;
localparam COM7_init = 8'h04;
localparam r_COM15 = 8'h40;
localparam COM15_init = 8'hD0;

logic sda_in, sda_oe;
assign c_SDA = sda_oe ? 1'b0 : 1'bz;
assign sda_in = c_SDA;

logic init_done_tick;
init init_i(.clk(clk_100), .reset, .sda_in, .sda_oe, .init_done_tick, .scl(c_SCL), .ipaddr(selected_ip), .done_btn(setup_btn_db), .sw_i);

// Declare an intermediate unpacked array
logic [3:0] ip_array [8];

// Map the packed vector to the unpacked array elements
always_comb begin
    for (int i = 0; i < 8; i++) begin
        // Maps [31:28] to index 0, [27:24] to index 1, etc.
        ip_array[i] = selected_ip[31 - (i*4) -: 4]; 
    end
end

hex_driver hdA(.clk(clk_100), .reset, .in(ip_array), .hex_seg, .hex_grid);


endmodule