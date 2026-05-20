module cam_top(
    input logic clk_100, reset,

    //Control inputs
    input logic capture,
    input logic write_btn,
    input logic [15:0] sw_i,

    //Seven segment displays
    output logic [3:0] hex_grid_a, hex_grid_b,
    output logic [7:0] hex_seg_a, hex_seg_b,

    //Camera
    inout wire c_SDA,
    input logic c_PLK,
    input logic [7:0]c_D,
    input logic c_VS, c_HS,
    output logic c_SCL,
    output logic c_XLK,
    output logic c_RET, c_PWDN,

    //HDMI
    output logic hdmi_clk_n,
    output logic hdmi_clk_p,
    output logic [2:0] hdmi_tx_n,
    output logic [2:0] hdmi_tx_p,

    //Ethernet
    input           rmii_clocks_ref_clk,
    input           rmii_crs_dv,
    output          rmii_mdc,
    inout           rmii_mdio,
    input     [1:0] rmii_rx_data,
    output     [1:0] rmii_tx_data,
    output           rmii_tx_en
);

//Inputs
logic capture_db, write_btn_db;

sync_debounce sdbi (.Clk(clk_100), .d(capture), .q(capture_db));
sync_debounce sdbi2 (.Clk(clk_100), .d(write_btn), .q(write_btn_db));

//bram signals - transmit buffer
logic [16:0] br_addra, br_addrb;
logic [15:0] br_dina, br_douta, br_doutb;
logic br_ena, br_enb;
logic [1:0] br_wea;

//ram signals - receive buffer
logic [16:0] recv_addra, recv_addrb;
logic [15:0] recv_dina, recv_doutb;
logic recv_ena, recv_enb;
logic [1:0] recv_wea;

//timing signals
logic clk_25, clk_125, clk_locked;

//vga signals
logic [3:0] R_vga, B_vga, G_vga;
logic hs_vga, vs_vga, active_nblank;
logic [9:0] drawX, drawY;

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


// Receive buffer: Network -> buffer -> HDMI
dual_port_dist_ram dpdr_i2(.clk(clk_100), .ena(recv_ena), .enb(recv_enb), .wea(recv_wea),
                          .addra(recv_addra), .addrb(recv_addrb), .dina(recv_dina),
                          .doutb(recv_doutb));

clk_wiz_0 clk_wiz_i(.reset(reset), .clk_in1(clk_100), .clk_out1(clk_125), .clk_out2(clk_25), .locked(clk_locked));

vga_controller vga_i(.pixel_clk(clk_25), .reset(reset), .hs(hs_vga), .vs(vs_vga), .active_nblank, .drawX, .drawY, .sync());

color_map cmap_i(.active(active_nblank), .drawX, .drawY, .br_addrb(recv_addrb), .br_doutb(recv_doutb), .br_enb(recv_enb), .R(R_vga), .G(G_vga), .B(B_vga), .clk_25, .clk_125);

net net_i(.sys_clk(clk_100), .reset, .rmii_clocks_ref_clk, .rmii_crs_dv, .rmii_mdc, .rmii_mdio,
                     .rmii_rx_data, .rmii_tx_data, .rmii_tx_en, .send_buff_addr(br_addrb),
                     .send_buff_dout(br_doutb), .send_buff_en(br_enb), .recv_buff_addr(recv_addra),
                     .recv_buff_din(recv_dina), .recv_buff_en(recv_ena), .recv_buff_we(recv_wea));

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
reg_init rii (.clk(clk_100), .reset, .sda_in, .sda_oe, .init_done_tick, .scl(c_SCL));

hdmi_tx_0 hdmi_tx_i (
    //Clocking and Reset
    .pix_clk(clk_25),
    .pix_clkx5(clk_125),
    .pix_clk_locked(clk_locked),
    .rst(reset),
    //Color and Sync Signals
    .red(R_vga),
    .green(G_vga),
    .blue(B_vga),
    .hsync(hs_vga),
    .vsync(vs_vga),
    .vde(active_nblank),

    //aux Data (unused)
    .aux0_din(4'b0),
    .aux1_din(4'b0),
    .aux2_din(4'b0),
    .ade(1'b0),

    //Differential outputs
    .TMDS_CLK_P(hdmi_clk_p),
    .TMDS_CLK_N(hdmi_clk_n),
    .TMDS_DATA_P(hdmi_tx_p),
    .TMDS_DATA_N(hdmi_tx_n)
);

// hex_driver hdA(.clk(clk_100), .reset, .in({4'b0, 4'b0, sw_i[15:12], sw_i[11:8]}), .hex_seg(hex_seg_a), .hex_grid(hex_grid_a));
// hex_driver hdB(.clk(clk_100), .reset, .in({init_state[3:0], 4'b0, sw_i[7:4], sw_i[3:0]}), .hex_seg(hex_seg_b), .hex_grid(hex_grid_b));


endmodule