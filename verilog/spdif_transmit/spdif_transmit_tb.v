`timescale 1ns / 1ps

module spdif_transmit_tb;

    // Parameters
    localparam real CLK_FREQ     = 24_576_000;     // 24.576 MHz clock
    localparam real SPDIF_BAUD   = 12_288_000;     // 12.288 Mbps SPDIF rate for 192kHz
    localparam real CLK_PERIOD   = 1_000_000_000.0 / CLK_FREQ; // ~40.69 ns

    // DUT inputs
    reg         rst;
    reg         clk;
    reg  [31:0] data_left;
    reg  [31:0] data_right;
    reg         validity;
    reg  [3:0]  sample_rate_code;

    // DUT output
    wire        spdif_out;

    // Instantiate DUT
    spdif_transmit #(
        .SPDIF_BAUD(12_288_000),
        .CLK_FREQ(24_576_000)
    ) dut (
        .rst(rst),
        .clk(clk),
        .data_left(data_left),
        .data_right(data_right),
        .validity(validity),
        .sample_rate_code(sample_rate_code),
        .spdif_out(spdif_out)
    );

    // Clock generation (~40.69ns period)
    always #(CLK_PERIOD / 2) clk = (clk === 1'b0); 

    // Stimulus
    initial begin
        $display("Starting SPDIF transmitter test...");
        $dumpfile("spdif_transmit_tb.vcd");
        $dumpvars(0, spdif_transmit_tb);

        // Initial values
        rst = 1;
        data_left = 0;
        data_right = 0;
        validity = 0;
        sample_rate_code = 4'b1100; // 48kHz

        # (10 * CLK_PERIOD);
        rst = 0;

        // Stimulus: send several sample pairs
        repeat (20) begin
            data_left  = $random & 32'hFFFFFFFF;
            data_right = $random & 32'hFFFFFFFF;
            validity   = 0;
            #(256 * CLK_PERIOD); // Wait ~1 audio frame (2 subframes × 64 bits = 128 SPDIF bits)
        end

        $display("Simulation complete.");
        $finish;
    end

endmodule
