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

    reg [0:63] shift_data;
    reg [31:0] sent_left, sent_right;

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

        pin_i2s_data <= 0;
        @(negedge pin_i2s_fclk);

        // first 2 words will be ignored so send zeroes
        @(negedge pin_i2s_bclk);

        shift_data = {{32{1'b0}}, {32{1'b0}}};
        sent_left = shift_data[0:31];
        sent_right = shift_data[32:63];
    
        repeat (31) begin
            pin_i2s_data <= shift_data[0];
            shift_data <= shift_data<<1;
            @(negedge pin_i2s_bclk);
        end

        repeat (32) begin
        pin_i2s_data <= shift_data[0];
        shift_data <= shift_data<<1;
        @(negedge pin_i2s_bclk);
        end

        pin_i2s_data <= shift_data[0];

        repeat (10) begin
            @(negedge pin_i2s_bclk);

            shift_data = {{$random}, {$random}};
            sent_left = shift_data[0:31];
            sent_right = shift_data[32:63];
        
            repeat (31) begin
                pin_i2s_data <= shift_data[0];
                shift_data <= shift_data<<1;
                @(negedge pin_i2s_bclk);
            end
            
            repeat (32) begin
            pin_i2s_data <= shift_data[0];
            shift_data <= shift_data<<1;
            @(negedge pin_i2s_bclk);
            end

            pin_i2s_data <= shift_data[0];
        end

        // Wait and finish
        #1000;
        $finish;
    end

endmodule
