module splitstreamer (
    input wire pin_clk_24m576hz, // at some point, this should become the PLL output
    input wire pin_i2s_fclk,
    input wire pin_i2s_bclk,
    input wire pin_i2s_data,
    output reg pin_opt1,
    output reg pin_opt2,
);



spdif_core
ucore
(
    .clk_i()
)


endmodule