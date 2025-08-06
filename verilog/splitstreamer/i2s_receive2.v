module i2s_receive2 (
    input  wire        rst,         // Active high reset
    input  wire        clk,         // I2S bit clock (BCLK)
    input  wire        ws,          // I2S word select (LRCLK)
    input  wire        sd,          // I2S serial data
    output reg  [23:0] data_left,   // Left channel data
    output reg  [23:0] data_right  // Right channel data
);

reg sck = 0;
// Generate SPDIF bit clock, divided by 2 from the main clock
always @(posedge clk or posedge rst) begin
    if (rst) begin
        sck <= 0;
    end else begin
        sck <= ~sck; // Toggle SPDIF clock
    end
end


reg wsd; // Previous state of word select
reg wsdd; // Previous state of word select (for edge detection)

always @(posedge sck) begin
    wsd <= ws; // Store the current state of word select
    wsdd <= wsd; // Store the last state of word select
end

wire wsp = wsdd ^ wsd; // Update previous state of word select for edge detection

reg [4:0] counter; // Counter for bit position
always @(negedge sck or posedge rst)
    if (rst)
        counter <= 0; // Reset counter
    else if (wsp)
        counter <= 0; // Reset counter on word select change
    else if (counter < 24)
        counter <= counter + 1; // Increment counter for each bit received
    

reg [0:23] shift_reg; // Shift register for I2S data
always @(posedge sck or posedge rst) begin
    if (rst) begin
        shift_reg <= 24'b0; // Reset shift register
        data_left <= 24'b0; // Reset left channel data
        data_right <= 24'b0; // Reset right channel data    
    end else begin
        if(wsp)
            shift_reg <= 0; // Reset shift register on word select change
        
        if (counter < 24) 
            shift_reg[counter] <= sd; // Shift in the serial data   
        
        if (wsd && wsp)
            data_left <= shift_reg; // Capture left channel data

        if (!wsd && wsp) 
            data_right <= shift_reg; // Capture right channel data
    end
end

endmodule