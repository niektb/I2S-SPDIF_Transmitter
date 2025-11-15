`timescale 1ns / 1ps

module splitstreamer2_tb;

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
    splitstreamer2 uut (
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

    // Frame clock divider controls
    reg [5:0] bit_div_cnt = 0;
    reg       fclk_div_enabled = 0;
    localparam integer HALF_DIV = 32; // toggle every 32 bit clocks -> full LRCLK = 64 bit clocks

    // Generate initial glitches, then enable synchronous division from bit clock
    initial begin
        // start values
        pin_i2s_fclk = 0;
        fclk_div_enabled = 0;
        bit_div_cnt = 0;

        // initial delay before glitches
        #1500;

        // Produce a small glitch sequence (not synchronized to bitclock) to simulate startup jitter
        pin_i2s_fclk = 1;
        #80;
        pin_i2s_fclk = 0; // short glitch
        #100;
        pin_i2s_fclk = 1;
        #50;
        pin_i2s_fclk = 0;

        // Now wait for the next negedge of bit clock to start synchronous division
        @(negedge pin_i2s_bclk);
        bit_div_cnt = 0;
        // align the frame clock phase: set to 0 and enable divider; first toggle will happen after HALF_DIV negedges
        pin_i2s_fclk = 0;
        fclk_div_enabled = 1;
    end

    // Synchronous divider: driven by bit clock, toggles frame clock every HALF_DIV negedges
    always @(negedge pin_i2s_bclk) begin
        if (fclk_div_enabled) begin
            if (bit_div_cnt == HALF_DIV - 1) begin
                pin_i2s_fclk <= ~pin_i2s_fclk;
                bit_div_cnt <= 0;
            end else begin
                bit_div_cnt <= bit_div_cnt + 1;
            end
        end
    end

    reg [0:63] shift_data;
    reg [31:0] sent_left, sent_right;

    initial begin
        // VCD dump for waveform
        $dumpfile("splitstreamer2_tb.vcd");
        $dumpvars(0, splitstreamer2_tb);

        // Reset the DUT
        pin_user_sw = 0; // Assert reset
        // Wait for PLL lock (simulated)
        #10;
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
