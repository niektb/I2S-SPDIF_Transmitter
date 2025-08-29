module i2s_receive1 (
    input  wire        rst,         // Active high reset
    input  wire        rx_en,      // Enable signal for receiving data
    input  wire        clk,         // System clock   
    input  wire        sck,         // I2S bit clock (BCLK)
    input  wire        ws,          // I2S word select (LRCLK)
    input  wire        sd,          // I2S serial data
    output reg  [31:0] data_left,   // Left channel data
    output reg  [31:0] data_right  // Right channel data
);

reg [31:0] shift_reg; // Shift register for I2S data
reg wsd; // Previous state of word select
reg wsdd; // Previous state of word select (for edge detection)
reg wsp; // Previous state of word select (for edge detection)
reg data_left_enable; // Enable signal for left channel data
reg data_right_enable; // Enable signal for right channel data

always @(posedge clk) begin
    if (rst) begin
        shift_reg <= 32'b0; // Reset shift register
        data_left <= 32'b0; // Reset left channel data
        data_right <= 32'b0; // Reset right channel data    
        wsd <= 1'b0; // Reset word select state
        wsdd <= 1'b0; // Reset last word select state 
        data_left_enable <= 1'b0; // Disable left channel data      
        data_right_enable <= 1'b0; // Disable right channel data
    end else if (rx_en && sck) begin // this only works when CLK is 2x sck
        shift_reg <= {shift_reg[30:0], sd}; // Shift in the serial data
        wsd <= ws; // Store the current state of word select
        wsdd <= wsd; // Store the last state of word select
        
        if (data_left_enable) begin
            data_left <= shift_reg; // Capture left channel data
        end else if (data_right_enable) begin
            data_right <= shift_reg; // Capture right channel data
        end
    end
end

always @(*) begin
    wsp <= wsdd ^ wsd; // Update previous state of word select for edge detection
    data_left_enable <= (wsd == 1'b1) && (wsp == 1'b1); // Enable left channel data on rising edge of WS
    data_right_enable <= (wsd == 1'b0) && (wsp == 1'b1); // Enable right channel data on rising edge of WS
end

endmodule
