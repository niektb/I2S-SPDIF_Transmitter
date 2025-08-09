// Simple verilog module to test button functionality. Includes debouncing. Turns on LED when button is pressed. Button is active low and connected to pin_user_sw. Led is connected to green, ren, and blue pins.
module button_test
(
    input  wire pin_user_sw, // Button input
    input  wire pin_clk_12mhz,         // Clock input
    output wire green,       // Green LED output
    output wire red,         // Red LED output
    output wire blue         // Blue LED output
);

    reg [1:0] user_sw_ff = 2'b11; // Flip-flop for debouncing

    // Debounce the button press using a flip-flop
    always @(posedge pin_clk_12mhz) begin
        user_sw_ff <= {user_sw_ff[0], pin_user_sw};
    end

    // Turn on the green LED when the button is pressed (active low)
    assign green = user_sw_ff[1]; // Active low logic for button press

    // Turn on the red and blue LEDs when the button is pressed
    assign red = user_sw_ff[1];   // Active low logic for button press
    assign blue = user_sw_ff[1];  // Active low logic for button press

endmodule