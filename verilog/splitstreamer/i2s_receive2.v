module i2s_receive2 (
    input  wire        rst,         // Active high reset
    input  wire        sck,         // I2S bit clock (BCLK)
    input  wire        ws,          // I2S word select (LRCLK)
    input  wire        sd,          // I2S serial data
    output reg  [31:0] data_left,   // Left channel data
    output reg  [31:0] data_right  // Right channel data
);

reg wsd; // Previous state of word select
always @(posedge sck)
    wsd <= ws; // Store the current state of word select

reg wsdd; // Previous state of word select (for edge detection)
always @(posedge sck)
    wsdd <= wsd; // Store the last state of word select

wire wsp = wsdd ^ wsd; // Update previous state of word select for edge detection

reg [5:0] counter; // Counter for bit position
always @(negedge sck or posedge rst)
    if (rst)
        counter <= 0; // Reset counter
    else if (wsp)
        counter <= 0; // Reset counter on word select change
    else if (counter < 32)
        counter <= counter + 1; // Increment counter for each bit received
    

reg [0:31] shift_reg; // Shift register for I2S data
always @(posedge sck or posedge rst) begin
    if (rst) begin
        shift_reg <= 32'b0; // Reset shift register
        data_left <= 32'b0; // Reset left channel data
        data_right <= 32'b0; // Reset right channel data    
    end else begin
        if(wsp)
            shift_reg <= 0; // Reset shift register on word select change
        
        if (counter < 32) 
            shift_reg[counter] <= sd; // Shift in the serial data   
        
        if (wsd && wsp)
            data_left <= shift_reg; // Capture left channel data

        if (!wsd && wsp) 
            data_right <= shift_reg; // Capture right channel data
    end
end

endmodule