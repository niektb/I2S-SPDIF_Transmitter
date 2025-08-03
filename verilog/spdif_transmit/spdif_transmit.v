module spdif_transmit (
    input  wire        rst,         // Active high reset
    input  wire        clk,         // System clock (must be much faster than SPDIF bit rate)
    input  wire [31:0] data_left,   // Left channel data
    input  wire [31:0] data_right,  // Right channel data
    output reg         spdif_out    // SPDIF output signal
);

    // Parameters for SPDIF bit rate and system clock
    parameter SPDIF_BAUD = 3072000; // 3.072 Mbps for 48kHz audio
    parameter CLK_FREQ   = 12288000; // Example: 12.288 MHz system clock
    localparam CLK_DIV = CLK_FREQ / SPDIF_BAUD;

    reg [15:0] clk_cnt = 0;
    reg        spdif_clk = 0;

    // Generate SPDIF bit clock
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_cnt <= 0;
            spdif_clk <= 0;
        end else begin
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= 0;
                spdif_clk <= ~spdif_clk; // Toggle SPDIF clock
            end else begin
                clk_cnt <= clk_cnt + 1;
            end 
        end
    end

    // Example: output a simple toggling pattern (replace with real BMC encoding)
    reg [7:0] frame = 8'b10110010;
    reg [2:0] idx = 0;

    always @(negedge spdif_clk or posedge rst) begin
        if (rst) begin
            idx   <= 0;
        end else begin
            idx   <= (idx == 7) ? 0 : idx + 1;
        end
    end


    reg Q1 = 0, Q2 = 0; // BMC encoding states
    always @(*)
        spdif_out <= Q1 ^ Q2; // Biphase Mark Coding (BMC) signal

    wire Q1_pre = frame[idx] ^ Q1;
    wire Q2_pre = !Q2;

    always @(negedge spdif_clk) begin
        Q1 <= Q1_pre; 
    end

    always @(posedge spdif_clk) begin
        Q2 <= Q2_pre;
    end

endmodule