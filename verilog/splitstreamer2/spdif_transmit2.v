module spdif_transmit2 (
    input  wire        rst,
    input  wire        clk,                // bit_clock: 128x Fsample
    input  wire [31:0] data_left,          // 24 bits valid, left-justified
    input  wire [31:0] data_right,         // 24 bits valid, left-justified
    input  wire        validity,           // validity bit
    input  wire [3:0]  sample_rate_code,   // IEC60958 sample rate code
    output reg         spdif_out
);

    // Channel status word (24 bits used here, can be expanded to 192)
    reg [23:0] channel_status = 24'b001000000000000001000000;
    reg [23:0] channel_status_shift = 24'b001000000000000001000000;

    reg [23:0] data_in_buffer = 0;
    reg [5:0]  bit_counter = 0;
    reg [8:0]  frame_counter = 0;
    reg        parity = 0;
    reg [7:0]  data_out_buffer = 0;
    reg        data_biphase = 0;

    // Sample rate code assignment (bits 23:20 or as needed)
    always @(*) begin
        channel_status[23:20] = sample_rate_code;
    end

    // Bit counter
    always @(posedge clk) begin
        if (rst)
            bit_counter <= 0;
        else
            bit_counter <= bit_counter + 1;
    end

    // Data latch and frame counter
    always @(posedge clk) begin
        if (rst) begin
            data_in_buffer <= 0;
            frame_counter  <= 0;
            parity         <= 0;
        end else begin
            // Latch new sample every 4th bit (bit_counter == 3)
            if (bit_counter == 6'd3) begin
                if (frame_counter[0] == 1'b1)
                    data_in_buffer <= data_left[31:8]; // 24 MSBs
                else
                    data_in_buffer <= data_right[31:8]; // 24 MSBs
            end

            // Parity calculation (XOR of all bits + channel status)
            parity <= ^data_in_buffer ^ channel_status_shift[23];

            // Frame counter update
            if (bit_counter == 6'd63) begin
                if (frame_counter == 9'd383)
                    frame_counter <= 0;
                else
                    frame_counter <= frame_counter + 1;
            end
        end
    end

    // Data output buffer
    always @(posedge clk) begin
        if (rst) begin
            data_out_buffer <= 0;
            channel_status_shift <= channel_status;
        end else begin
            if (bit_counter == 6'd63) begin
                // Load preamble and channel status for new frame
                if (frame_counter == 9'd383) begin
                    // Preamble Z
                    data_out_buffer <= 8'b10011100;
                    channel_status_shift <= channel_status;
                end else if (frame_counter[0] == 1'b1) begin
                    // Preamble X (even frame)
                    data_out_buffer <= 8'b10010011;
                    channel_status_shift <= {channel_status_shift[22:0], 1'b0};
                end else begin
                    // Preamble Y (odd frame)
                    data_out_buffer <= 8'b10010110;
                    // channel_status_shift unchanged
                end
            end else if (bit_counter[2:0] == 3'b111) begin
                case (bit_counter[5:3])
                    3'b000: data_out_buffer <= {1'b1, data_in_buffer[0], 1'b1, data_in_buffer[1], 1'b1, data_in_buffer[2], 1'b1, data_in_buffer[3]};
                    3'b001: data_out_buffer <= {1'b1, data_in_buffer[4], 1'b1, data_in_buffer[5], 1'b1, data_in_buffer[6], 1'b1, data_in_buffer[7]};
                    3'b010: data_out_buffer <= {1'b1, data_in_buffer[8], 1'b1, data_in_buffer[9], 1'b1, data_in_buffer[10], 1'b1, data_in_buffer[11]};
                    3'b011: data_out_buffer <= {1'b1, data_in_buffer[12], 1'b1, data_in_buffer[13], 1'b1, data_in_buffer[14], 1'b1, data_in_buffer[15]};
                    3'b100: data_out_buffer <= {1'b1, data_in_buffer[16], 1'b1, data_in_buffer[17], 1'b1, data_in_buffer[18], 1'b1, data_in_buffer[19]};
                    3'b101: data_out_buffer <= {1'b1, data_in_buffer[20], 1'b1, data_in_buffer[21], 1'b1, data_in_buffer[22], 1'b1, data_in_buffer[23]};
                    3'b110: data_out_buffer <= {5'b10101, channel_status_shift[23], 1'b1, parity};
                    default: data_out_buffer <= 8'b0;
                endcase
            end else begin
                data_out_buffer <= {data_out_buffer[6:0], 1'b0};
            end
        end
    end

    // Biphase mark encoding
    always @(posedge clk) begin
        if (rst)
            data_biphase <= 0;
        else if (data_out_buffer[7])
            data_biphase <= ~data_biphase;
    end

    always @(posedge clk)
        spdif_out <= data_biphase;

endmodule