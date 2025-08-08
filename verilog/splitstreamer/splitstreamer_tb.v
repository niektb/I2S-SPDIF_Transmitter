`timescale 1ns / 1ps

module splitstreamer_tb;

    // Inputs
    reg pin_i2s_bclk_pll ;
    reg pin_i2s_fclk ;
    reg pin_i2s_bclk;
    reg pin_i2s_data;
    reg pin_user_sw = 1; // Active low reset
    // Outputs
    wire red;
    wire pin_opt1;

    // Instantiate the DUT
    splitstreamer uut (
        .pin_i2s_bclk_pll(pin_i2s_bclk_pll),
        .pin_i2s_fclk(pin_i2s_fclk),
        .pin_i2s_bclk(pin_i2s_bclk),
        .pin_i2s_data(pin_i2s_data),
        .red(red),
        .pin_opt1(pin_opt1),
        .pin_user_sw(pin_user_sw)
    );

    // Clocks
    always #20 pin_i2s_bclk_pll = (pin_i2s_bclk_pll === 1'b0);  // 25 MHz PLL output clock
    always #40 pin_i2s_bclk = (pin_i2s_bclk === 1'b0);          // 12.5 MHz I2S bit clock
    always #2560 pin_i2s_fclk = (pin_i2s_fclk === 1'b0);

    initial begin
        // VCD dump for waveform
        $dumpfile("splitstreamer_tb.vcd");
        $dumpvars(0, splitstreamer_tb);

        // Reset the DUT
        pin_user_sw = 0; // Assert reset
        // Wait for PLL lock (simulated)
        #100;
        // Release reset
        pin_user_sw = 1;

        send_i2s_word($random, 0);

        // Reset the DUT
        pin_user_sw = 0; // Assert reset
        // Wait for PLL lock (simulated)
        #100;
        // Release reset
        pin_user_sw = 1;

        // Send I2S data (simulate stereo frame)
        repeat (200) begin
            // Left channel: 0x12345678
            send_i2s_word($random, 0);
            // Right channel: 0x9ABCDEF0
            send_i2s_word($random, 1);
        end

        // Wait and finish
        #1000;
        $finish;
    end

    // I2S word sender (MSB first)
    task send_i2s_word(input [31:0] word, input channel);
        integer i;
        begin
            pin_i2s_fclk = channel;
            for (i = 31; i >= 0; i = i - 1) begin
                pin_i2s_data = word[i];
                @(negedge pin_i2s_bclk);
            end
        end
    endtask

endmodule
