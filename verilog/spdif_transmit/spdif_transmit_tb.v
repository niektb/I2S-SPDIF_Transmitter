`timescale 1ns/1ns

module spdif_transmit_tb;

  reg clk = 0;
  always #50 clk = ~clk; // 10 MHz clock

  reg rst = 1;
  initial begin
    repeat(10) @(posedge clk);
    rst = 0;
  end

  reg [31:0] data_left = 0;
  reg [31:0] data_right = 0;

  // Instantiate DUT
  spdif_transmit dut (
    .rst(rst),
    .clk(clk),
    .data_left(data_left),
    .data_right(data_right),
    .spdif_out(spdif_out)
  );

  initial begin
    $dumpfile("spdif_transmit_tb.vcd");
    $dumpvars(0, spdif_transmit_tb);
    @(negedge rst); // Wait for reset deassertion
    @(posedge clk);
    data_left  = $random;
    data_right = $random;
    repeat(200) @(posedge clk);    
    $finish;
  end

endmodule
