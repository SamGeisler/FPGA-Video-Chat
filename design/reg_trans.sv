module cam_i2c #(
    parameter int CLK_DIV = 250,       // 100 MHz / (2*250) ~= 200 kHz phase rate, ~100 kHz SCL
    parameter logic [7:0] DEV_ADDR_W = 8'h42,
    parameter logic [7:0] DEV_ADDR_R = 8'h43
)(
    input  logic       clk_100,
    input  logic       reset,

    input  logic       trigger,        // 1-cycle pulse is fine
    input  logic       rw,             // 0 = write register, 1 = read register
    input  logic [7:0] reg_addr,
    input  logic [7:0] write_data,

    output logic [7:0] read_data,
    output logic       busy,
    output logic       done,

    output logic       scl,
    input  logic       sda_in,
    output logic       sda_drive_low   // 1 = pull SDA low, 0 = release SDA
);

    typedef enum logic [4:0] {
        ST_IDLE,

        ST_START_A,
        ST_START_B,

        ST_SEND_BIT_LOW,
        ST_SEND_BIT_HIGH,

        ST_ACK_LOW,
        ST_ACK_HIGH,

        ST_RESTART_A,
        ST_RESTART_B,
        ST_RESTART_C,

        ST_READ_BIT_LOW,
        ST_READ_BIT_HIGH,

        ST_MASTER_NACK_LOW,
        ST_MASTER_NACK_HIGH,

        ST_STOP_A,
        ST_STOP_B,
        ST_STOP_C,

        ST_DONE
    } state_t;

    state_t state;

    logic [$clog2(CLK_DIV)-1:0] divcnt;
    logic tick;

    logic pending;
    logic pending_rw;
    logic [7:0] pending_reg_addr;
    logic [7:0] pending_write_data;

    logic [7:0] cur_byte;
    logic [2:0] bit_idx;

    logic [1:0] tx_phase;
    // tx_phase:
    //   write op: 0=DEV_ADDR_W, 1=REG_ADDR, 2=WRITE_DATA
    //   read  op: 0=DEV_ADDR_W, 1=REG_ADDR, 2=DEV_ADDR_R

    logic ack_ignored;

    always_ff @(posedge clk_100 or posedge reset) begin
        if (reset) begin
            divcnt <= '0;
            tick   <= 1'b0;
        end else begin
            if (divcnt == CLK_DIV-1) begin
                divcnt <= '0;
                tick   <= 1'b1;
            end else begin
                divcnt <= divcnt + 1'b1;
                tick   <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk_100 or posedge reset) begin
        if (reset) begin
            state            <= ST_IDLE;
            pending          <= 1'b0;
            pending_rw       <= 1'b0;
            pending_reg_addr <= 8'h00;
            pending_write_data <= 8'h00;
            read_data        <= 8'h00;
            busy             <= 1'b0;
            done             <= 1'b0;
            scl              <= 1'b1;
            sda_drive_low    <= 1'b0;
            cur_byte         <= 8'h00;
            bit_idx          <= 3'd7;
            tx_phase         <= 2'd0;
            ack_ignored      <= 1'b1;
        end else begin
            done <= 1'b0;

            if (trigger && !pending && !busy) begin
                pending            <= 1'b1;
                pending_rw         <= rw;
                pending_reg_addr   <= reg_addr;
                pending_write_data <= write_data;
            end

            if (tick) begin
                case (state)
                    ST_IDLE: begin
                        busy          <= 1'b0;
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0;

                        if (pending) begin
                            pending       <= 1'b0;
                            busy          <= 1'b1;
                            tx_phase      <= 2'd0;
                            cur_byte      <= DEV_ADDR_W;
                            bit_idx       <= 3'd7;
                            state         <= ST_START_A;
                        end
                    end

                    ST_START_A: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b1;
                        state         <= ST_START_B;
                    end

                    ST_START_B: begin
                        scl           <= 1'b0;
                        sda_drive_low <= ~cur_byte[bit_idx];
                        state         <= ST_SEND_BIT_LOW;
                    end

                    ST_SEND_BIT_LOW: begin
                        scl           <= 1'b0;
                        sda_drive_low <= ~cur_byte[bit_idx];
                        state         <= ST_SEND_BIT_HIGH;
                    end

                    ST_SEND_BIT_HIGH: begin
                        scl <= 1'b1;

                        if (bit_idx == 3'd0) begin
                            state <= ST_ACK_LOW;
                        end else begin
                            bit_idx <= bit_idx - 3'd1;
                            state   <= ST_SEND_BIT_LOW;
                        end
                    end

                    ST_ACK_LOW: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b0;
                        state         <= ST_ACK_HIGH;
                    end

                    ST_ACK_HIGH: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0;
                        ack_ignored   <= sda_in;

                        if (!pending_rw) begin
                            // WRITE: DEVW -> REG -> DATA -> STOP
                            if (tx_phase == 2'd0) begin
                                tx_phase  <= 2'd1;
                                cur_byte  <= pending_reg_addr;
                                bit_idx   <= 3'd7;
                                state     <= ST_SEND_BIT_LOW;
                            end else if (tx_phase == 2'd1) begin
                                tx_phase  <= 2'd2;
                                cur_byte  <= pending_write_data;
                                bit_idx   <= 3'd7;
                                state     <= ST_SEND_BIT_LOW;
                            end else begin
                                state <= ST_STOP_A;
                            end
                        end else begin
                            // READ: DEVW -> REG -> RESTART -> DEVR -> READ BYTE -> NACK -> STOP
                            if (tx_phase == 2'd0) begin
                                tx_phase  <= 2'd1;
                                cur_byte  <= pending_reg_addr;
                                bit_idx   <= 3'd7;
                                state     <= ST_SEND_BIT_LOW;
                            end else if (tx_phase == 2'd1) begin
                                tx_phase  <= 2'd2;
                                cur_byte  <= DEV_ADDR_R;
                                bit_idx   <= 3'd7;
                                state     <= ST_RESTART_A;
                            end else begin
                                bit_idx   <= 3'd7;
                                read_data <= 8'h00;
                                state     <= ST_READ_BIT_LOW;
                            end
                        end
                    end

                    // --- SCCB Read Phase Fix ---
                    // Replaces ST_RESTART_A, B, C to create a true STOP followed by a START 
                    ST_RESTART_A: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b1; // Pull SDA low while SCL is low
                        state         <= ST_RESTART_B;
                    end

                    ST_RESTART_B: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b1; // SCL goes high, SDA stays low
                        state         <= ST_RESTART_C;
                    end

                    ST_RESTART_C: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0; // Release SDA while SCL is high -> Valid STOP!
                        state         <= ST_START_A; // Next tick naturally pulls SDA low -> Valid START!
                    end


                    // --- I2C/SCCB Valid STOP Fix ---
                    // Replaces ST_STOP_A, B to ensure SCL is high BEFORE SDA goes high
                    ST_STOP_A: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b1; // Pull SDA low
                        state         <= ST_STOP_B;
                    end

                    ST_STOP_B: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b1; // SCL goes high, SDA stays low
                        state         <= ST_STOP_C;
                    end

                    ST_STOP_C: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0; // Release SDA while SCL is high -> Valid STOP!
                        state         <= ST_DONE;
                    end

                    ST_READ_BIT_LOW: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b0;
                        state         <= ST_READ_BIT_HIGH;
                    end

                    ST_READ_BIT_HIGH: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0;

                        read_data[bit_idx] <= sda_in;

                        if (bit_idx == 3'd0) begin
                            state <= ST_MASTER_NACK_LOW;
                        end else begin
                            bit_idx <= bit_idx - 3'd1;
                            state   <= ST_READ_BIT_LOW;
                        end
                    end

                    // Final byte of read: master sends NACK by releasing SDA
                    ST_MASTER_NACK_LOW: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b0;
                        state         <= ST_MASTER_NACK_HIGH;
                    end

                    ST_MASTER_NACK_HIGH: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0;
                        state         <= ST_STOP_A;
                    end

                    ST_DONE: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0;
                        busy          <= 1'b0;
                        done          <= 1'b1;
                        state         <= ST_IDLE;
                    end

                    default: begin
                        state <= ST_IDLE;
                    end
                endcase
            end
        end
    end

endmodule