// Testbench for button_test module
`timescale 1ns / 1ps

module button_test_tb;

    reg pin_user_sw; // Button input
    reg pin_clk_12mhz;         // Clock input
    wire green;     // Green LED output
    wire red;       // Red LED output
    wire blue;      // Blue LED output

    // Instantiate the button_test module
    button_test uut (
        .pin_user_sw(pin_user_sw),
        .pin_clk_12mhz(pin_clk_12mhz),
        .green(green),
        .red(red),
        .blue(blue)
    );

    // Clock generation
    initial begin
        pin_clk_12mhz = 0;
        forever #5 pin_clk_12mhz = ~pin_clk_12mhz; // 10 ns clock period
    end

    // Test sequence
    initial begin
        $dumpfile("button_test_tb.vcd");
        $dumpvars(0, button_test_tb);

        // Initialize inputs
        pin_user_sw = 1; // Button not pressed

        // Wait for a few clock cycles
        #20;

        // Press the button (active low)
        pin_user_sw = 0;
        #10; // Wait for a few clock cycles

        // Release the button
        pin_user_sw = 1;
        #20; // Wait for a few clock cycles

        // End simulation
        $finish;
    end

endmodule