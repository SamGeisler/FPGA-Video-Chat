module test_i2c_top(
    input clk_100, reset,
    inout wire c_SDA,
    output logic c_SCL, 
    output logic c_XLK,
    output logic c_RET, c_PWDN,

    input btn,

    output  logic   [7:0]   hex_seg,
    output  logic   [3:0]   hex_grid
);

localparam REG_WRITE = 0;
localparam REG_READ = 1;
localparam r_COM7 =8'h12;
localparam r_COM15 = 8'h40;

logic btn_db;

sync_debounce sdbi (.Clk(clk_100), .d(btn), .q(btn_db));

logic clk_25, clk_125, clk_locked;

assign c_RET = ~reset;
assign c_PWDN = 0;
assign c_XLK = clk_25;

clk_wiz_0 clk_wiz_i(.reset(reset), .clk_in1(clk_100), .clk_out1(clk_125), .clk_out2(clk_25), .locked(clk_locked));


logic sda_in, sda_oe;
assign c_SDA = sda_oe ? 1'b0 : 1'bz;
assign sda_in = c_SDA;

logic start_tick, done_tick, rw;
logic [7:0] reg_addr, data_r, data_w;

cam_i2c cam_i2c_i (.clk_100, .reset, .trigger(start_tick), .rw, .reg_addr(reg_addr), .write_data(data_w),
                       .read_data(data_r), .busy(), .done(done_tick), .scl(c_SCL), .sda_in, .sda_drive_low(sda_oe));


logic [7:0] hex_display_val;


logic [3:0] state;

logic [23:0] init_delay;
logic init_ready;

localparam r_PID = 8'h0A; // expected 8'h76
localparam r_VER = 8'h0B; // often 8'h73

// COM7 <- 0x04, COM15 <- 0xD0
always_ff @(posedge clk_100 or posedge reset) begin
    if(reset) begin
        init_delay <= 0;
        init_ready <= 0;
        state <= 0;
        start_tick <= 0;
        rw <= REG_WRITE;
        reg_addr <= 0;
        data_w <= 0;
        hex_display_val <= 8'h00;
    end else begin
        if(!init_ready) begin
            if(clk_locked) begin
                init_delay <= init_delay + 1;
                if(init_delay == 24'd5_000_000)
                init_ready <= 1;
            end
        end else begin
            if(state == 0) begin
                start_tick <= 1;
                rw <= REG_WRITE;
                reg_addr <= r_COM7;
                data_w <= 8'h04;
                state <= 1;
            end else if(state == 1) begin
                start_tick <= 0;
                if(done_tick)
                    state <= 2;
            end else if(state == 2) begin
                start_tick <= 1;
                rw <= REG_READ;
                reg_addr <= r_COM7;
                state <= 3;
            end else if(state == 3) begin
                start_tick <= 0;
                if(done_tick)
                    state <= 4;
            end else if(state == 4) begin
                hex_display_val <= data_r;
                if(btn_db) begin
                    state <= 5;
                end
            end else if(state == 5) begin
                if(~btn_db) begin
                    state <= 0;
                end
            end 
        end
    end
end


hex_driver HexA (
    .clk        (clk_100),
    .reset      (reset),

    .in         ({state, 4'h0, hex_display_val[7:4], hex_display_val[3:0]}),
    .hex_seg    (hex_seg),
    .hex_grid   (hex_grid)
);
            

/* Double read test:

            if(state == 0) begin
                start_tick <= 1;
                rw <= REG_READ;
                reg_addr <= r_PID;
                state <= 1;
            end else if(state == 1) begin
                start_tick <= 0;
                if(done_tick)
                    state <= 2;
            end else if(state == 2) begin
                hex_display_val <= data_r;
                if(btn_db) begin
                    state <= 3;
                end
            end else if(state == 3) begin
                if(~btn_db) begin
                    state <= 4;
                end
            end else if(state == 4) begin
                start_tick <= 1;
                rw <= REG_READ;
                reg_addr <= r_VER;
                state <= 5;
            end else if(state == 5) begin
                start_tick <= 0;
                if(done_tick)
                    state <= 6;
            end else if(state == 6) begin
                hex_display_val <= data_r;
                if(btn_db) begin
                    state <= 7;
                end
            end else if(state == 7) begin
                if(~btn_db) begin
                    state <= 0;
                end
            end 
*/

endmodule