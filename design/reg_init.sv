`timescale 1ns / 1ps

module reg_init(
    input clk, reset,
    
    input sda_in,

    output logic init_done_tick,
                 sda_oe,
                 scl
);

localparam [16:0] NUM_INIT_REGS = 11;
logic [15:0] inits[0:NUM_INIT_REGS-1]; // [addr, data]

initial begin
    inits[0] = 16'h12_04; // RGB mode
    inits[1] = 16'h40_D0; // RGB565 mode
    inits[2] = 16'h3A_05; // Change YUV order (?)
    inits[3] = 16'hb0_84; // Magically improves color (from internet)
    inits[4] = 16'h4F_96; // Matrix Coefficients
    inits[5] = 16'h50_83;
    inits[6] = 16'h51_00;
    inits[7] = 16'h52_3d;
    inits[8] = 16'h53_a7;
    inits[9] = 16'h54_c8;
    inits[10] = 16'h58_1a;
end

logic [31:0] delay_counter;
logic [16:0] word_counter;

typedef enum logic [4:0] {
    s_reset,
    s_delay,
    s_reg_write,
    s_reg_wait,
    s_done_tick,
    s_done
} state_t;

state_t state;

localparam REG_WRITE = 0;
logic [7:0] data_w, reg_addr;
logic start_tick, done_tick, rw;

cam_i2c cam_i2c_i (.clk_100(clk), .reset, .trigger(start_tick), .rw, .reg_addr(reg_addr), .write_data(data_w),
                       .read_data(), .busy(), .done(done_tick), .scl, .sda_in, .sda_drive_low(sda_oe));


always_ff @(posedge reset or posedge clk) begin
    if(reset)begin
        state <= s_reset;
        delay_counter <= 0;
        word_counter <= 0;
        init_done_tick <= 0;
    end else begin
        case(state)
            s_reset: begin
                state <= s_delay;
                delay_counter <= 0;
                word_counter <= 0;
            end
            s_delay: begin
                delay_counter <= delay_counter + 1;
                if(delay_counter == 32'd500_000) begin
                    state <= s_reg_write;
                end
            end
            s_reg_write: begin
                state <= s_reg_wait;
                rw <= REG_WRITE;
                reg_addr <= inits[word_counter][15:8];
                data_w <=  inits[word_counter][7:0];
                start_tick <= 1;
            end
            s_reg_wait: begin
                start_tick <= 0;
                if(done_tick == 1) begin
                    if(word_counter == NUM_INIT_REGS-1) begin
                        state <= s_done_tick;
                    end else begin
                        state <= s_delay;
                        word_counter <= word_counter + 1;
                        delay_counter <= 0;
                    end
                end
            end
            s_done_tick: begin
                state <= s_done;
                init_done_tick <= 1;
            end
            s_done: begin
                init_done_tick <= 0;
            end
        endcase
    end
end

endmodule
