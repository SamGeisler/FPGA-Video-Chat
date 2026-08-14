module arp_req (
    input clk, reset,

    output logic [7:0] sink_data,
    output logic sink_last,
    input sink_ready,
    output logic sink_valid,

    input [7:0] source_data,
    input source_last,
    output logic source_ready,
    input source_valid,

    output logic [47:0] addr,
    output logic addr_valid
);

localparam [15:0] HW_TYPE = 16'd1;
localparam [15:0] PROTOCOL_TYPE = 16'h0800;
localparam [7:0] HW_LEN = 8'd6;
localparam [7:0] PROTOCOL_LEN = 8'd4;

localparam [47:0] THIS_ETH_ADDR = 48'h10_e2_d5_00_00_00;
localparam [31:0] THIS_IP_ADDR = 32'hA9_FE_50_0B; //169.254.80.11

localparam [31:0] TARGET_IP_ADDR = 32'hA9_FE_50_0A; //169.254.80.10

localparam [15:0] OP_REQ = 1;
localparam [15:0] OP_REPLY = 2;

localparam [4:0] ARP_LEN = 28;

localparam [31:0] INIT_DELAY_CYCLES = 10_000_000;
localparam [31:0] REQ_TIMEOUT_CYCLES = 200_000_000;


logic [47:0] addr_n;
logic addr_valid_n;

logic [4:0] byte_counter, byte_counter_n;
logic [31:0] timer, timer_n;



typedef enum logic [3:0] {
    s_reset,
    s_init_delay,
    s_send_req,
    s_await_response,
    s_check_response,
    s_discard_response,
    s_finished
} state_t;

state_t state, state_n;

always_ff @(posedge clk) begin
    if(reset) begin
        state <= s_reset;
        addr <= 48'b0;
        addr_valid <= 0;
        timer <= 0;
        byte_counter <= 0;
    end else begin
        state <= state_n;
        byte_counter <= byte_counter_n;
        timer <= timer_n;
        addr <= addr_n;
        addr_valid <= addr_valid_n;
    end
end

always_comb begin
    automatic logic check_byte = 1;
    automatic logic [7:0] expected_byte;

    state_n = state;
    byte_counter_n = byte_counter;
    timer_n = timer;
    addr_n = addr;
    addr_valid_n = addr_valid;

    sink_data = 0;
    sink_last = 0;
    sink_valid = 0;
    source_ready = 0;

    case (state)
        s_reset: begin
            state_n = s_init_delay;
        end

        s_init_delay: begin
            timer_n = timer + 1;
            if(timer == INIT_DELAY_CYCLES-1) begin
                byte_counter_n = 0;
                state_n = s_send_req;
            end
        end

        s_send_req: begin
            case(byte_counter)
                0: sink_data = HW_TYPE[15:8];
                1: sink_data = HW_TYPE[7:0];
                2: sink_data = PROTOCOL_TYPE[15:8];
                3: sink_data = PROTOCOL_TYPE[7:0];
                4: sink_data = HW_LEN;
                5: sink_data = PROTOCOL_LEN;
                6: sink_data = OP_REQ[15:8];
                7: sink_data = OP_REQ[7:0];
                8: sink_data = THIS_ETH_ADDR[47:40];
                9: sink_data = THIS_ETH_ADDR[39:32];
                10: sink_data = THIS_ETH_ADDR[31:24];
                11: sink_data = THIS_ETH_ADDR[23:16];
                12: sink_data = THIS_ETH_ADDR[15:8];
                13: sink_data = THIS_ETH_ADDR[7:0];
                14: sink_data = THIS_IP_ADDR[31:24];
                15: sink_data = THIS_IP_ADDR[23:16];
                16: sink_data = THIS_IP_ADDR[15:8];
                17: sink_data = THIS_IP_ADDR[7:0];
                // Target HW address field ignored - 18, 19, 20, 21, 22, 23
                24: sink_data = TARGET_IP_ADDR[31:24];
                25: sink_data = TARGET_IP_ADDR[23:16];
                26: sink_data = TARGET_IP_ADDR[15:8];
                27: begin   
                    sink_data = TARGET_IP_ADDR[7:0];
                    sink_last = 1;
                end
            endcase
            sink_valid = 1;

            if(sink_ready) begin
                if(byte_counter == ARP_LEN-1) begin
                    state_n = s_await_response;
                    timer_n = 0;
                end else
                    byte_counter_n = byte_counter + 1;
            end
        end

        s_await_response: begin
            byte_counter_n = 0;
            if(source_valid) begin
                state_n = s_check_response;
            end else begin
                if(timer == REQ_TIMEOUT_CYCLES-1) 
                    state_n = s_send_req;
                else
                    timer_n = timer + 1;
            end
        end

        s_check_response: begin
            source_ready = 1;
            if(source_valid) begin
                case (byte_counter)
                    0, 1: check_byte = 0; // HW Type
                    2: expected_byte = PROTOCOL_TYPE[15:8];
                    3: expected_byte = PROTOCOL_TYPE[7:0];
                    4, 5: check_byte = 0; // Len
                    6: expected_byte = OP_REPLY[15:8];
                    7: expected_byte = OP_REPLY[7:0];
                    8, 9, 10, 11, 12, 13: check_byte = 0; // Sender eth address
                    14: expected_byte = TARGET_IP_ADDR[31:24];
                    15: expected_byte = TARGET_IP_ADDR[23:16];
                    16: expected_byte = TARGET_IP_ADDR[15:8];
                    17: expected_byte = TARGET_IP_ADDR[7:0];
                    18, 19, 20, 21, 22, 23: check_byte = 0; // Target eth address
                    24, 25, 26, 27: check_byte = 0; // Target ip address
                endcase
                if(check_byte && expected_byte != source_data)
                    state_n = s_discard_response;

                case (byte_counter)
                    8: addr_n[47:40] = source_data;
                    9: addr_n[39:32] = source_data;
                    10: addr_n[31:24] = source_data;
                    11: addr_n[23:16] = source_data;
                    12: addr_n[15:8] = source_data;
                    13: addr_n[7:0] = source_data;
                endcase
                
                if(byte_counter == ARP_LEN-1) begin
                    if(source_last)
                        state_n = s_finished;
                end else
                    byte_counter_n = byte_counter + 1;
            end
        end

        s_discard_response: begin
            source_ready = 1;
            if(source_valid) begin
                if(source_last) begin
                    state_n = s_init_delay;
                    timer_n = 0;
                end
            end
        end

        s_finished: begin
            addr_valid_n = 1;
        end
    endcase

end


endmodule
