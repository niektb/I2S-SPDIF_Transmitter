// SPDX-License-Identifier: MIT
// IEC60958 (S/PDIF) transmitter, 24-bit audio payload
// - Correct B/M/W preambles (8 BMC half-cells each)
// - MSB-first data, then V/U/C, then parity (even over 27 bits)
// - BMC encoding: start toggle every bit, mid-toggle if data=1
//
// clk = 24.576 MHz, symbol (half-cell) rate = 12.288 MHz
// so we use a simple /2 clock-enable for half-cell updates.

module spdif_transmit (
    input  wire        rst,
    input  wire        clk,               // 24.576 MHz
    input  wire [31:0] data_left,         // use [23:0]
    input  wire [31:0] data_right,        // use [23:0]
    input  wire        validity,          // V-bit (0 = valid)
    input  wire [3:0]  sample_rate_code,  // placed in channel-status[27:24]
    output reg         spdif_out
);
    // --------- Clocking (half-cell enable) ----------
    parameter SPDIF_BAUD = 12288000; // half-cell rate
    parameter CLK_FREQ   = 24576000; // clk
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

    // --------- Channel-status (192-bit, L/R identical here) ----------
    reg [191:0] ch_status = 192'b0;
    // insert sample rate code at bits [27:24]
    always @(*) begin
        // keep others zero; user can extend
        // Note: synthesis treats this as combinational fan-in to the reads below.
        ch_status[27:24] = sample_rate_code;
    end

    reg [7:0] cs_idx = 8'd0;  // 0..191, increments each subframe (L then R)

    // --------- B/M/W preambles in BMC half-cell domain (8 half-cells) ----------
    // These are "illegal" BMC patterns used solely for sync.
    localparam [7:0] PREAMBLE_B = 8'b1110_1000; // start-of-block, left
    localparam [7:0] PREAMBLE_M = 8'b1110_0010; // left (not start-of-block)
    localparam [7:0] PREAMBLE_W = 8'b1110_0100; // right

    // --------- Subframe assembly (28 bits: [27:4]=audio, [3]=V, [2]=U, [1]=C, [0]=P) ----------
    function [27:0] make_subframe;
        input [31:0] audio_data;   // use [23:0]
        input        validity_bit; // 1=invalid, 0=valid per IEC
        input        user_bit;
        input        channel_status_bit;
        reg   [27:0] temp;
        reg          parity;
        integer      i;
    begin
        temp = 28'd0;
        temp[27:4] = audio_data[23:0];
        temp[3]    = validity_bit;
        temp[2]    = user_bit;
        temp[1]    = channel_status_bit;

        // Even parity over bits [27:1], put in [0]
        parity = 1'b0;
        for (i = 1; i <= 27; i = i + 1)
            parity = parity ^ temp[i];
        temp[0] = parity;

        make_subframe = temp;
    end
    endfunction

    // --------- Framing / LR / block state ----------
    reg        lr = 1'b0;           // 0=left, 1=right
    reg [8:0]  frame_count = 9'd0;  // 0..191 (count left frames only)

    // --------- BMC encoder + preamble injector ----------
    reg        bmc_out = 1'b0;
    reg        bmc_phase = 1'b0;     // 0 = first half of bit, 1 = second half
    reg        in_preamble = 1'b0;
    reg [2:0]  pre_cnt = 3'd0;       // 0..7 within preamble
    reg [7:0]  pre_shift = 8'd0;

    reg [27:0] shift_data = 28'd0;   // MSB first at [27]
    reg  [5:0] bit_ptr = 6'd27;      // 27..0

    // convenience wires for current CS bit
    wire cs_bit = ch_status[cs_idx];

    // Subframe select
    wire [27:0] subframe_left  = make_subframe(data_left,  validity, 1'b0, cs_bit);
    wire [27:0] subframe_right = make_subframe(data_right, validity, 1'b0, cs_bit);

    // Next preamble type selector
    function [7:0] pick_preamble;
        input is_left;
        input is_start_of_block;
    begin
        if (is_left && is_start_of_block)
            pick_preamble = PREAMBLE_B;
        else if (is_left)
            pick_preamble = PREAMBLE_M;
        else
            pick_preamble = PREAMBLE_W;
    end
    endfunction

    // Core state machine: advances on each half-cell (ce)
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
        end else begin
            if (ce) begin
                // If we're idle between subframes, start a new one by issuing a preamble.
                if (!in_preamble && (bmc_phase == 1'b0) && (bit_ptr == 6'd27) && (shift_data == 28'd0)) begin
                    // load subframe & preamble
                    shift_data <= (lr == 1'b0) ? subframe_left : subframe_right;
                    pre_shift  <= pick_preamble((lr == 1'b0), (lr == 1'b0) && (frame_count == 9'd0));
                    in_preamble <= 1'b1;
                    pre_cnt     <= 3'd0;
                end

                if (in_preamble) begin
                    // Emit preamble (8 half-cells), LSB-first of pre_shift[7:0] or MSB-first?
                    // We defined pre_shift so that we output [7] first for readability.
                    // So emit MSB first:
                    spdif_out <= pre_shift[7];
                    pre_shift <= {pre_shift[6:0], 1'b0};
                    pre_cnt   <= pre_cnt + 3'd1;
                    if (pre_cnt == 3'd7) begin
                        in_preamble <= 1'b0;
                        bmc_phase   <= 1'b0;  // start fresh for first data bit
                    end
                end else begin
                    // Normal BMC encoding for data bits
                    if (bmc_phase == 1'b0) begin
                        // Start of bit cell: always toggle
                        bmc_out   <= ~bmc_out;
                        spdif_out <= bmc_out; // update output after toggle
                        bmc_phase <= 1'b1;
                    end else begin
                        // Mid-bit cell: toggle only if data bit is 1
                        if (shift_data[27]) begin
                            bmc_out <= ~bmc_out;
                        end
                        spdif_out <= bmc_out;

                        // Advance to next data bit
                        bmc_phase  <= 1'b0;
                        shift_data <= {shift_data[26:0], 1'b0};

                        if (bit_ptr == 6'd0) begin
                            // Subframe complete -> prepare for next subframe on next half-cell
                            bit_ptr <= 6'd27;
                            // LR toggle, frame/block count, channel-status index
                            if (lr == 1'b1) begin
                                // finished Right -> next is Left, increment frame_count 0..191
                                lr <= 1'b0;
                                frame_count <= (frame_count == 9'd191) ? 9'd0 : (frame_count + 9'd1);
                            end else begin
                                // finished Left -> next is Right
                                lr <= 1'b1;
                            end
                            // Channel-status advances each subframe
                            cs_idx <= (cs_idx == 8'd191) ? 8'd0 : (cs_idx + 8'd1);

                            // clear shift_data so we can detect "need new preamble" path at top
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
