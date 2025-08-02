module rgb_led (
    input wire pin_clk_12mhz,
    output reg red,
    output reg green,
    output reg blue
);

    // 12,000,000 clock cycles = 1 second at 12 MHz
    localparam integer ONE_SEC_COUNT = 12_000_000;
    reg [23:0] counter = 0;
    reg [1:0] color_state = 0;
    reg ready_n = 1;

    always @(posedge pin_clk_12mhz) begin
        if (ready_n) begin
            ready_n <= 0;
            counter <= 0;
            color_state <= 0;
        end else begin
            if (counter < ONE_SEC_COUNT - 1) begin
                counter <= counter + 1;
            end else begin
                counter <= 0;
                color_state <= color_state + 1;
            end
        end
    end

    always @(*) begin
        case (color_state)
            2'b00: begin red = 1; green = 0; blue = 0; end // Red
            2'b01: begin red = 0; green = 1; blue = 0; end // Green
            2'b10: begin red = 0; green = 0; blue = 1; end // Blue
            default: begin red = 0; green = 0; blue = 0; end // Off
        endcase
    end
endmodule