// SPDX-License-Identifier: MIT
// IEC60958 (S/PDIF) transmitter, 24-bit audio payload
// - Correct B/M/W preambles with polarity selection
// - MSB-first 24-bit audio, then V/U/C, then parity
// - BMC encoding for data bits

module spdif_transmit (
    input  wire        rst,
    input  wire        clk,               // 24.576 MHz
    input  wire [31:0] data_left,         // use [23:0]
    input  wire [31:0] data_right,        // use [23:0]
    input  wire        validity,          // 0 = valid, 1 = invalid
    input  wire [3:0]  sample_rate_code,  // placed in channel-status[27:24]
    output reg         spdif_out
);

    // --------- Clocking (half-cell enable) ----------
    parameter CLK_FREQ   = 24576000;  // input clk
    parameter SPDIF_BAUD = 12288000;  // half-cell rate
    localparam integer CLK_DIV = CLK_FREQ / SPDIF_BAUD; // expect 2

    reg [$clog2(CLK_DIV)-1:0] divcnt = 0;
    reg ce = 1'b0; // pulses once per half-cell

    always @(posedge clk) begin
        if (rst) begin
            divcnt <= 0;
            ce     <= 1'b0;
        end else begin
            if (divcnt == CLK_DIV-1) begin
                divcnt <= 0;
                ce     <= 1'b1;
            end else begin
                divcnt <= divcnt + 1'b1;
                ce     <= 1'b0;
            end
        end
    end

    // --------- Channel-status (192-bit) ----------
    reg [191:0] ch_status = 192'b0;
    always @(*) begin
        ch_status[27:24] = sample_rate_code;
    end

    reg [7:0] cs_idx = 8'd0;  // 0..191

    // --------- Preambles (positive and negative) ----------
    // Values are 8 half-cell sequences in BMC domain
    localparam [7:0] PRE_B_POS = 8'b11101000;
    localparam [7:0] PRE_B_NEG = 8'b00010111;
    localparam [7:0] PRE_M_POS = 8'b11100010;
    localparam [7:0] PRE_M_NEG = 8'b00011101;
    localparam [7:0] PRE_W_POS = 8'b11100100;
    localparam [7:0] PRE_W_NEG = 8'b00011011;

    // --------- Subframe assembly (28 bits) ----------
    function [27:0] make_subframe;
        input [31:0] audio_data;
        input        validity_bit;
        input        user_bit;
        input        channel_status_bit;
        reg   [27:0] temp;
        reg          parity;
    begin
        temp = 28'd0;
        temp[27:4] = audio_data[31:8];
        temp[3]    = validity_bit;
        temp[2]    = user_bit;
        temp[1]    = channel_status_bit;
        
        temp[0] = ^temp[27:1]; // even parity
        parity = temp[0];

        make_subframe = temp;
    end
    endfunction

    // --------- Framing state ----------
    reg        lr = 1'b0;          // 0=left, 1=right
    reg [8:0]  frame_count = 9'd0; // counts left frames 0..191

    // --------- Encoder state ----------
    reg        bmc_out = 1'b0;
    reg        bmc_phase = 1'b0;
    reg        in_preamble = 1'b0;
    reg [2:0]  pre_cnt = 3'd0;
    reg [7:0]  pre_shift = 8'd0;
    reg [27:0] shift_data = 28'd0;
    reg [5:0]  bit_ptr = 6'd27;

    wire cs_bit = ch_status[cs_idx];
    wire [27:0] subframe_left  = make_subframe(data_left,  validity, 1'b0, cs_bit);
    wire [27:0] subframe_right = make_subframe(data_right, validity, 1'b0, cs_bit);

    // Pick preamble based on channel/position and current line state
    function [7:0] pick_preamble;
        input is_left;
        input is_start_of_block;
        input line_state;
    begin
        if (is_left && is_start_of_block)
            pick_preamble = line_state ? PRE_B_NEG : PRE_B_POS;
        else if (is_left)
            pick_preamble = line_state ? PRE_M_NEG : PRE_M_POS;
        else
            pick_preamble = line_state ? PRE_W_NEG : PRE_W_POS;
    end
    endfunction

    // --------- Main FSM ----------
    always @(posedge clk) begin
        if (rst) begin
            lr           <= 1'b0;
            frame_count  <= 9'd0;
            cs_idx       <= 8'd0;
            in_preamble  <= 1'b0;
            pre_cnt      <= 3'd0;
            pre_shift    <= 8'd0;
            shift_data   <= 28'd0;
            bit_ptr      <= 6'd27;
            bmc_out      <= 1'b0;
            bmc_phase    <= 1'b0;
            spdif_out    <= 1'b0;
        end else if (ce) begin
            if (in_preamble) begin
                // Emit preamble sequence
                spdif_out <= pre_shift[7];
                pre_shift <= {pre_shift[6:0], 1'b0};
                pre_cnt   <= pre_cnt + 3'd1;
                if (pre_cnt == 3'd7) begin
                    in_preamble <= 1'b0;
                    bmc_phase   <= 1'b0;
                end
            end else begin
                if (shift_data == 28'd0 && bmc_phase == 1'b0 && bit_ptr == 6'd27) begin
                    // Start new subframe: load data + preamble
                    shift_data <= (lr == 1'b0) ? subframe_left : subframe_right;
                    pre_shift  <= pick_preamble(
                                    (lr == 1'b0),
                                    (lr == 1'b0) && (frame_count == 9'd0),
                                    bmc_out);
                    in_preamble <= 1'b1;
                    pre_cnt     <= 3'd0;
                end else begin
                    // Normal BMC data encoding
                    if (bmc_phase == 1'b0) begin
                        bmc_out   <= ~bmc_out;
                        spdif_out <= ~bmc_out;
                        bmc_phase <= 1'b1;
                    end else begin
                        if (shift_data[27])
                            bmc_out <= ~bmc_out;
                        spdif_out <= bmc_out;
                        bmc_phase  <= 1'b0;
                        shift_data <= {shift_data[26:0], 1'b0};
                        if (bit_ptr == 6'd0) begin
                            bit_ptr <= 6'd27;
                            if (lr == 1'b1) begin
                                lr <= 1'b0;
                                frame_count <= (frame_count == 9'd191) ? 9'd0 : frame_count + 9'd1;
                            end else begin
                                lr <= 1'b1;
                            end
                            cs_idx <= (cs_idx == 8'd191) ? 8'd0 : cs_idx + 8'd1;
                            shift_data <= 28'd0;
                        end else begin
                            bit_ptr <= bit_ptr - 6'd1;
                        end
                    end
                end
            end
        end
    end
endmodule
