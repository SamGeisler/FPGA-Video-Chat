module init(
    input clk, reset, 
    input sda_in, done_btn,
    input [15:0] sw_i,

    output logic sda_oe, 
                 scl, 
                 init_done_tick,
    
    output logic [31:0] ipaddr
);

// Instantiate reg_init
// Once done_btn pressed twice and reg_init tick received, send done tick


localparam DEFAULT_IP = 32'h??;

typedef enum logic [2:0] {
    s_first_hw,
    s_second_hw,
    s_await_reg_init,
    s_do_tick,
    s_done
} state_t;

state_t input_state;

logic [1:0] done_btn_staged;
assign done_btn_tick = done_btn_staged[0] && ~done_btn_staged[1];
always_ff @(posedge clk)
    done_btn_staged <= {done_btn_staged[0], done_btn};

logic reg_done, reg_done_latched;
always_ff @(posedge clk)
    reg_done_latched <= reg_done_latched ? 1 : reg_done;

assign init_done_tick = input_state==s_do_tick;

always_ff @(posedge clk, posedge reset) begin
    if(reset) begin
        ipaddr <= 0;
        if(sw_i[0]) begin
            ipaddr <= DEFAULT_IP;
            input_state <= s_done;
        end else begin
            ipaddr <= 0;
            input_state <= s_first_hw;
        end
    end else begin
        // Next state logic
        case(input_state)
            s_first_hw: 
                if(done_btn_tick)
                    input_state <= s_second_hw;
            s_second_hw:
                if(done_btn_tick)
                    input_state <= s_await_reg_init;
            s_await_reg_init:
                if(reg_done_latched)
                    input_state <= s_do_tick;
            s_do_tick:
                input_state <= s_done;
        endcase

        // Value to show on hex displays
        case(input_state)
            s_first_hw:
                ipaddr <= {sw_i, ipaddr[15:0]};
            s_second_hw:
                ipaddr <= {ipaddr[31:16], sw_i};
        endcase
    end
end

reg_init reg_init_i (.clk, .reset, .init_done_tick(reg_done), .sda_in, .sda_oe, .scl);

endmodule