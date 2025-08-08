`define SIM

module splitstreamer (
    input wire pin_i2s_bclk_pll, // at some point, this should become the PLL output
    input wire pin_i2s_bclk, // I2S bit clock
    input wire pin_i2s_fclk,
    input wire pin_i2s_data,
    input wire pin_user_sw, // Active low reset
    output wire red,
    output wire green,
    output wire blue,
    output wire pin_opt1,
    output wire pin_opt2,
    output wire pin_i2s_out_data // This is the SPDIF output to pinheader
);

wire clk; // Main clock for the design
wire pll_lock;
wire smu_full;
wire smu_empty;
wire smu_write_en;
wire smu_read_en;
wire smu_rst;
wire [31:0] fifo_in_data_left;
wire [31:0] fifo_in_data_right;
wire [31:0] fifo_out_data_left;
wire [31:0] fifo_out_data_right;
wire [31:0] fifo_out_data_left_reverse;
wire [31:0] fifo_out_data_right_reverse;
wire smu_validity;

wire optical_out;

assign pin_opt1 = optical_out; // SPDIF output to pin_opt1
assign pin_opt2 = optical_out; // SPDIF output to pin_opt2
assign pin_i2s_out_data = optical_out; // I2S output to pinheader

`ifndef SIM
SB_PLL40_CORE #(
    .FEEDBACK_PATH("SIMPLE"),
    .DIVR(4'b0000), // Divide by 1
    .DIVF(7'b0111111), // Multiply by 64
    .DIVQ(3'b101), // Divide by 4
    .FILTER_RANGE(3'b001) // Moderate filter range
) pll_inst (
    .REFERENCECLK(pin_i2s_bclk_pll),
    .PLLOUTGLOBAL(clk),
    .RESETB(1'b1), // No reset
    .BYPASS(1'b0), // Not bypassed
    .LOCK(pll_lock) // Lock signal for PLL
);

`else
assign clk = pin_i2s_bclk_pll; // For simulation, use the input
assign pll_lock = 1'b1; // Simulate PLL lock
`endif

i2s_receive1 in (
    .rst(smu_rst), // Assuming no reset for simplicity
    .sck(pin_i2s_bclk),
    .ws(pin_i2s_fclk),
    .sd(pin_i2s_data),
    .data_left(fifo_in_data_left),   // Left channel data output
    .data_right(fifo_in_data_right)   // Right channel data output
);

fifo #(
    .WORDSIZE(32),
    .DEPTH(16)
) buffer (
    .rst(smu_rst), // Assuming no reset for simplicity
    .clk(pin_i2s_fclk),
    .write_en(smu_write_en), // Always write for this example
    .read_en(smu_read_en),  // No read operation in this example
    .data_left_in(fifo_in_data_left),
    .data_right_in(fifo_in_data_right),
    .data_left_out(fifo_out_data_left), // Not used in this example
    .data_right_out(fifo_out_data_right), // Not used in this example
    .full(smu_full), // Full signal not used in this example
    .empty(smu_empty) // Empty signal not used in this example
);

reverse_bits #(
    .WIDTH(32)
) reverse_left (
    .in(fifo_out_data_left),
    .out(fifo_out_data_left_reverse) // Reverse bits for left channel
);

reverse_bits #(
    .WIDTH(32)
) reverse_right (
    .in(fifo_out_data_right),
    .out(fifo_out_data_right_reverse) // Reverse bits for right channel
);

// Instantiate the SPDIF transmitter
spdif_transmit out (
    .rst(smu_rst),
    .clk(clk),
    .data_left(fifo_out_data_left_reverse),
    .data_right(fifo_out_data_right_reverse),
    .validity(smu_read_en), // Assuming always valid for this example
    .sample_rate_code(4'b1100), // Example sample rate code
    .spdif_out(optical_out) // Output to pin_opt1
);

system_management_unit smu (
    .pin_user_sw(pin_user_sw),
    .clk(clk),
    .pll_lock(pll_lock), // Use the PLL lock signal
    .pin_i2s_fclk(pin_i2s_fclk),
    .full(smu_full), // Full signal from FIFO not used in this example
    .empty(smu_empty), // Empty signal from FIFO not used in this example
    .red(red), // Red LED for lock status
    .green(green), // Green LED for lock status
    .blue(blue), // Blue LED for lock status
    .write_en(smu_write_en), // Write enable signal not used in this example
    .read_en(smu_read_en), // Read enable signal not used in this example
    .rst(smu_rst) // Reset signal not used in this example
);

endmodule

module system_management_unit
(
    input  wire pin_user_sw,
    input  wire clk,
    input  wire pll_lock,
    input  wire pin_i2s_fclk,
    input  wire full,
    input  wire empty,
    output wire red,
    output wire green,
    output wire blue,
    output wire write_en,
    output wire read_en,
    output wire rst
);

    // monitor reset signal and lock signal to trigger reset
    assign rst = ~pll_lock | ~state_bclk;

    reg state_fclk = 0;
    // monitor that a full fclk period has passed before allowing writes
    always @(posedge pin_i2s_fclk) begin
        if (rst) begin
            state_fclk <= 0;
        end else begin
            if (state_fclk == 0) begin
                state_fclk <= 1; // Allow write after first fclk period
            end
        end
    end

    // run pin_user_sw through 2 flip flops to debounce the switch
    reg [1:0] user_sw_ff = 2'b00;
    always @(posedge clk) begin
        user_sw_ff <= {user_sw_ff[0], pin_user_sw};
    end     

    reg state_bclk = 0;
    // monitor that a full fclk period has passed before allowing writes
    always @(posedge clk) begin
        if (user_sw_ff[1] == 1'b0 && user_sw_ff[0] == 1'b1) begin
            state_bclk <= 0;
        end else begin
            if (state_bclk == 0 && user_sw_ff[1] == 1) begin
                state_bclk <= 1; // Allow write after first bclk period
            end
        end
    end 
            
    assign read_en = ~empty && state_fclk; // Allow read if not empty and state is set
    assign write_en = ~full && state_fclk; // Allow write if not full and state is set
    assign red = ~pll_lock; // Red LED indicates lock status
    assign blue = ~pll_lock; // Red LED indicates lock status
    assign green = ~pll_lock; // Red LED indicates lock status

endmodule

module reverse_bits #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);

genvar i;
generate
    for (i = 0; i < WIDTH; i = i + 1) begin : bit_reverse
        assign out[i] = in[WIDTH-1 - i];
    end
endgenerate

endmodule