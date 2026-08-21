`timescale 1ns / 1ps
module arp_engine (
    input clk, reset,

    input logic [7:0] sink_data,
    input logic sink_last,
    output logic sink_ready,
    input logic sink_valid,

    output logic [7:0] source_data,
    output logic source_last,
    input logic source_ready,
    output logic source_valid,

    output logic [47:0] addr,
    output logic addr_valid
);

//Split the transmitter and receiver 
//Transmitter uses same loop as before, except that if a reply needs to be sent, it is interrupted
//Receiver indicates to the transmitter that a reply needs to be sent, or if the address is resolved

localparam [15:0] HW_TYPE = 16'd1;
localparam [15:0] PROTOCOL_TYPE = 16'h0800;
localparam [7:0] HW_LEN = 8'd6;
localparam [7:0] PROTOCOL_LEN = 8'd4;

localparam [47:0] THIS_ETH_ADDR = 48'h10_e2_d5_00_00_00;
localparam [31:0] THIS_IP_ADDR = 32'hA9_FE_50_0B; //169.254.80.11

localparam [31:0] TARGET_IP_ADDR = 32'hA9_FE_50_0A; //169.254.80.10

localparam [15:0] OP_REQUEST = 1;
localparam [15:0] OP_REPLY = 2;

localparam [4:0] ARP_LEN = 28;

localparam [31:0] INIT_DELAY_CYCLES = 10_000_000;
localparam [31:0] REQ_TIMEOUT_CYCLES = 200_000_000;


//Transmission variables
logic [47:0] addr_n;
logic addr_valid_n;

logic [4:0] trans_byte, trans_byte_n;
logic [31:0] timer, timer_n;



//Transmission-reception bridge variables
logic need_to_reply, replied, replied_n;
logic [47:0] reply_target_mac;
logic [31:0] reply_target_ip;


typedef enum logic [3:0] {
    s_reset,
    s_init_delay,
    s_check_pending,
    s_send_request,
    s_send_reply,
    s_idle
} trans_state_t;

trans_state_t trans_state, trans_state_n;




always_ff @(posedge clk) begin
    if(reset) begin
        trans_state <= s_reset;
        addr <= 48'b0;
        addr_valid <= 0;
        timer <= 0;
        trans_byte <= 0;
        replied <= 0;
    end else begin
        trans_state <= trans_state_n;
        trans_byte <= trans_byte_n;
        timer <= timer_n;
        addr <= addr_n;
        addr_valid <= addr_valid_n;
        replied <= replied_n;
    end
end


always_comb begin
    trans_state_n = trans_state;
    trans_byte_n = trans_byte;
    timer_n = timer;
    addr_n = addr;
    addr_valid_n = addr_valid;
    replied_n = replied;

    source_data = 0;
    source_last = 0;
    source_valid = 0;

    case (trans_state)
        s_reset: begin
            trans_state_n = s_init_delay;
        end

        s_init_delay: begin
            timer_n = timer + 1;
            if(timer == INIT_DELAY_CYCLES-1) 
                trans_state_n = s_check_pending;
        end

        s_check_pending: begin
            trans_byte_n = 0;
            if(need_to_reply) 
                trans_state_n = s_send_reply;
            else
                trans_state_n = s_send_request;
        end

        s_send_request: begin
            case(trans_byte)
                0: source_data = HW_TYPE[15:8];
                1: source_data = HW_TYPE[7:0];
                2: source_data = PROTOCOL_TYPE[15:8];
                3: source_data = PROTOCOL_TYPE[7:0];
                4: source_data = HW_LEN;
                5: source_data = PROTOCOL_LEN;
                6: source_data = OP_REQUEST[15:8];
                7: source_data = OP_REQUEST[7:0];
                8: source_data = THIS_ETH_ADDR[47:40];
                9: source_data = THIS_ETH_ADDR[39:32];
                10: source_data = THIS_ETH_ADDR[31:24];
                11: source_data = THIS_ETH_ADDR[23:16];
                12: source_data = THIS_ETH_ADDR[15:8];
                13: source_data = THIS_ETH_ADDR[7:0];
                14: source_data = THIS_IP_ADDR[31:24];
                15: source_data = THIS_IP_ADDR[23:16];
                16: source_data = THIS_IP_ADDR[15:8];
                17: source_data = THIS_IP_ADDR[7:0];
                // Target HW address field ignored - 18, 19, 20, 21, 22, 23
                24: source_data = TARGET_IP_ADDR[31:24];
                25: source_data = TARGET_IP_ADDR[23:16];
                26: source_data = TARGET_IP_ADDR[15:8];
                27: begin   
                    source_data = TARGET_IP_ADDR[7:0];
                    source_last = 1;
                end
            endcase
            source_valid = 1;

            if(source_ready) begin
                if(trans_byte == ARP_LEN-1) begin
                    trans_state_n = s_idle;
                    timer_n = 0;
                end else
                    trans_byte_n = trans_byte + 1;
            end
        end

        s_send_reply: begin
            case(trans_byte)
                0: source_data = HW_TYPE[15:8];
                1: source_data = HW_TYPE[7:0];
                2: source_data = PROTOCOL_TYPE[15:8];
                3: source_data = PROTOCOL_TYPE[7:0];
                4: source_data = HW_LEN;
                5: source_data = PROTOCOL_LEN;
                6: source_data = OP_REPLY[15:8];
                7: source_data = OP_REPLY[7:0];
                8: source_data = THIS_ETH_ADDR[47:40];
                9: source_data = THIS_ETH_ADDR[39:32];
                10: source_data = THIS_ETH_ADDR[31:24];
                11: source_data = THIS_ETH_ADDR[23:16];
                12: source_data = THIS_ETH_ADDR[15:8];
                13: source_data = THIS_ETH_ADDR[7:0];
                14: source_data = THIS_IP_ADDR[31:24];
                15: source_data = THIS_IP_ADDR[23:16];
                16: source_data = THIS_IP_ADDR[15:8];
                17: source_data = THIS_IP_ADDR[7:0];
                18: source_data = reply_target_mac[47:40];
                19: source_data = reply_target_mac[39:32];
                20: source_data = reply_target_mac[31:24];
                21: source_data = reply_target_mac[23:16];
                22: source_data = reply_target_mac[15:8];
                23: source_data = reply_target_mac[7:0];
                24: source_data = TARGET_IP_ADDR[31:24];
                25: source_data = TARGET_IP_ADDR[23:16];
                26: source_data = TARGET_IP_ADDR[15:8];
                27: begin   
                    source_data = TARGET_IP_ADDR[7:0];
                    source_last = 1;
                end
            endcase
            source_valid = 1;

            if(source_ready) begin
                if(trans_byte == ARP_LEN-1) begin
                    trans_state_n = s_idle;
                    replied_n = 1;
                end else
                    trans_byte_n = trans_byte + 1;
            end
        end

        s_idle: begin
            replied_n = 0;

            if(timer == REQ_TIMEOUT_CYCLES) begin
                timer_n = 0;
                if(~addr_valid) begin
                    trans_state_n = s_send_request;
                end
            end else begin
                timer_n = timer + 1;
            end

            if(~replied && need_to_reply) begin
                trans_state_n = s_send_reply;
                trans_byte_n = 0;
            end
        end
    endcase
end


//Reception
logic [4:0] recv_byte;
logic trash_packet;
logic [15:0] latched_op;
logic [47:0] addr_temp;

always_ff @(posedge clk) begin
    automatic logic check_byte = 1;
    automatic logic [7:0] expected_byte;


    if(reset) begin
        addr <= 0;
        addr_valid <= 0;

        recv_byte <= 0;
        sink_ready <= 0;
        trash_packet <= 0;
        latched_op <= 0;
        addr_temp <= 0;
        
        need_to_reply <= 0;
        reply_target_mac <= 0;
        reply_target_ip <= 0;
    end else begin
        if(~need_to_reply) begin
            need_to_reply <= 0;
            sink_ready <= 1;
            if(sink_valid) begin

                if(~trash_packet) begin

                    // Verify arp packet
                    case (recv_byte)
                        0: expected_byte = HW_TYPE[15:8];
                        1: expected_byte = HW_TYPE[7:0];
                        2: expected_byte = PROTOCOL_TYPE[15:8];
                        3: expected_byte = PROTOCOL_TYPE[7:0];
                        4: expected_byte = HW_LEN;
                        5: expected_byte = PROTOCOL_LEN;
                        6, 7: check_byte = 0; // Operation;
                        8, 9, 10, 11, 12, 13: check_byte = 0; // Sender eth address
                        14: 
                            if(latched_op == OP_REPLY) 
                                expected_byte = TARGET_IP_ADDR[31:24];
                            else
                                check_byte = 0;
                        15: 
                            if(latched_op == OP_REPLY) 
                                expected_byte = TARGET_IP_ADDR[23:16];
                            else
                                check_byte = 0;
                        16: 
                            if(latched_op == OP_REPLY) 
                                expected_byte = TARGET_IP_ADDR[15:8];
                            else
                                check_byte = 0;
                        17: 
                            if(latched_op == OP_REPLY) 
                                expected_byte = TARGET_IP_ADDR[7:0];
                            else
                                check_byte = 0;

                        18, 19, 20, 21, 22, 23: check_byte = 0; // Target eth address
                        24, 25, 26, 27: check_byte = 0; // Target ip address
                    endcase

                    if(check_byte && expected_byte != sink_data) begin
                        trash_packet <= 0;
                        recv_byte <= 0;
                    end

                    // Latch operation
                    case (recv_byte)
                        6: latched_op[15:8] <= sink_data;
                        7: latched_op[7:0] <= sink_data;
                    endcase


                    // Latch info from request or reply
                    if(latched_op == OP_REPLY) begin
                        case(recv_byte)
                            8: addr_temp[47:40] <= sink_data;
                            9: addr_temp[39:32] <= sink_data;
                            10: addr_temp[31:24] <= sink_data;
                            11: addr_temp[23:16] <= sink_data;
                            12: addr_temp[15:8] <= sink_data;
                            13: addr_temp[7:0] <= sink_data;
                        endcase
                    end else if (latched_op == OP_REQUEST) begin
                        case(recv_byte)
                            8: reply_target_mac[47:40] <= sink_data;
                            9: reply_target_mac[39:32] <= sink_data;
                            10: reply_target_mac[31:24] <= sink_data;
                            11: reply_target_mac[23:16] <= sink_data;
                            12: reply_target_mac[15:8] <= sink_data;
                            13: reply_target_mac[7:0] <= sink_data;
                            14: reply_target_ip[31:24] <= sink_data;
                            15: reply_target_ip[23:16] <= sink_data;
                            16: reply_target_ip[15:8] <= sink_data;
                            17: reply_target_ip[7:0] <= sink_data;
                        endcase
                    end

                    
                    if(recv_byte == ARP_LEN-1) begin
                        if(sink_last) begin
                            recv_byte <= 0;

                            if(latched_op == OP_REPLY) begin
                                addr <= addr_temp;
                                addr_valid <= 1;
                            end else if(latched_op == OP_REQUEST) begin
                                need_to_reply <= 1;
                            end
                        end
                    end else
                        recv_byte <= recv_byte + 1;

                end

            end
        end
    end
end

endmodule
