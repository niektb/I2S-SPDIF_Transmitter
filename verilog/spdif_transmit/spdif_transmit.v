module spdif_transmit (
    input  wire        rst,
    input  wire        clk,
    input  wire [31:0] data_left,
    input  wire [31:0] data_right,
    input  wire        validity,
    input  wire [3:0]  sample_rate_code,
    output reg         spdif_out
);

    // Parameters for 192kHz
    parameter SPDIF_BAUD = 12288000; // 12.288 Mbps
    parameter CLK_FREQ   = 24576000; // 24.576 MHz
    localparam CLK_DIV = 2;

    // channel status word
    reg [191:0] ch_status_left  = 192'b0;
    reg [191:0] ch_status_right = 192'b0;

    always @(*) begin
        ch_status_left[27:24]  = sample_rate_code;
        ch_status_right[27:24] = sample_rate_code;
    end

    reg spdif_clk = 0;
    // Generate SPDIF bit clock, divided by 2 from the main clock
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            spdif_clk <= 0;
        end else begin
            spdif_clk <= ~spdif_clk; // Toggle SPDIF clock
        end
    end

    reg [7:0] ch_status_idx = 0;
    wire channel_status_bit_left  = ch_status_left[ch_status_idx];
    wire channel_status_bit_right = ch_status_right[ch_status_idx];

    // Subframe generation (without preamble)
    reg [27:0] subframe_data_left;
    reg [27:0] subframe_data_right;
    always @* begin
        subframe_data_left  = make_subframe(data_left, validity, 1'b0, channel_status_bit_left);
        subframe_data_right = make_subframe(data_right, validity, 1'b0, channel_status_bit_right);
    end

    // frame/block management
    reg [5:0] bit_idx = 0;
    reg       lr = 0;     // left/right
    reg [9:0] frame_count = 0; // block frame counter

    reg [27:0] shift_data;
    reg [3:0]  preamble_code;
    reg [3:0]  preamble_type;

    always @(negedge spdif_clk or posedge rst) begin
        if (rst) begin
            bit_idx <= 0;
            lr <= 0;
            frame_count <= 0;
        end else begin
            if (bit_idx == 31) begin
                bit_idx <= 0;
                lr <= ~lr;
                if (lr)
                    frame_count <= (frame_count == 191) ? 0 : frame_count + 1;
            end else begin
                bit_idx <= bit_idx + 1;
            end
        end
    end

    // BMC encoder state
    reg bmc_out = 0;
    reg bmc_phase = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bmc_out <= 0;
            bmc_phase <= 0;
            shift_data <= 0;
            preamble_type <= 4'b0000;
        end
        else begin
            if (bit_idx == 0) begin
                // new subframe
                if (lr == 0) begin
                    shift_data <= subframe_data_left;
                    // decide preamble
                    if (frame_count == 0)
                        preamble_type <= 4'b0001; // B
                    else
                        preamble_type <= 4'b0010; // M
                end
                else begin
                    shift_data <= subframe_data_right;
                    preamble_type <= 4'b0011; // W
                end
            end

            if (bit_idx < 4) begin
                // preamble bits override
                case (preamble_type)
                    4'b0001: // B preamble
                        bmc_out <= preamble_b(bit_idx);
                    4'b0010: // M preamble
                        bmc_out <= preamble_m(bit_idx);
                    4'b0011: // W preamble
                        bmc_out <= preamble_w(bit_idx);
                    default:
                        bmc_out <= 1;
                endcase
            end
            else begin
                // BMC encoding of bits 27..0
                if (bmc_phase == 0) begin
                    // always toggle start
                    bmc_out <= ~bmc_out;
                    bmc_phase <= 1;
                end else begin
                    if (shift_data[27])
                        bmc_out <= ~bmc_out; // extra transition for 1
                    else
                        bmc_out <= bmc_out; // 1 transition for 0
                    bmc_phase <= 0;

                    // shift down
                    shift_data <= {shift_data[26:0], 1'b0};
                end
            end
        end
    end

    always @(negedge clk)
        spdif_out <= bmc_out;

    // subframe creation function
    function [27:0] make_subframe;
        input [31:0] audio_data;
        input        validity;
        input        user;
        input        channel_status;
        reg   [27:0] temp;
        reg          parity;
        integer      i;
        begin
            temp = 28'b0;
            temp[27:4] = audio_data[23:0];
            temp[3] = validity;
            temp[2] = user;
            temp[1] = channel_status;

            parity = 0;
            for (i = 0; i < 27; i = i + 1)
                parity = parity ^ temp[i];
            temp[0] = parity;
            make_subframe = temp;
        end
    endfunction

    // preamble patterns for first 4 bits (in transitions)
    function preamble_b;
        input [5:0] idx;
        begin
            // e.g. B preamble code: 1110
            case (idx)
                0: preamble_b = 1'b1;
                1: preamble_b = 1'b1;
                2: preamble_b = 1'b1;
                3: preamble_b = 1'b0;
                default: preamble_b = 1'b0;
            endcase
        end
    endfunction
    function preamble_m;
        input [5:0] idx;
        begin
            case (idx)
                0: preamble_m = 1'b1;
                1: preamble_m = 1'b1;
                2: preamble_m = 1'b0;
                3: preamble_m = 1'b0;
                default: preamble_m = 1'b0;
            endcase
        end
    endfunction
    function preamble_w;
        input [5:0] idx;
        begin
            case (idx)
                0: preamble_w = 1'b1;
                1: preamble_w = 1'b0;
                2: preamble_w = 1'b0;
                3: preamble_w = 1'b0;
                default: preamble_w = 1'b0;
            endcase
        end
    endfunction

endmodule
