`timescale 1ns/1ns

module fifo_tb;

  parameter WORDSIZE = 32;
  parameter DEPTH = 8;

  reg clk = 0;
  always #50 clk = ~clk; // 10 MHz clock

  reg rst = 1;
  initial begin
    repeat(10) @(posedge clk);
    rst = 0;
  end

  reg write_en = 0, read_en = 0;
  reg [WORDSIZE-1:0] data_left_in = 0;
  reg [WORDSIZE-1:0] data_right_in = 0;
  wire [WORDSIZE-1:0] data_left_out, data_right_out;
  wire full, empty;

  // Instantiate DUT
  fifo #(.WORDSIZE(WORDSIZE), .DEPTH(DEPTH)) dut (
    .rst(rst),
    .clk(clk),
    .write_en(write_en),
    .read_en(read_en),
    .data_left_in(data_left_in),
    .data_right_in(data_right_in),
    .data_left_out(data_left_out),
    .data_right_out(data_right_out),
    .full(full),
    .empty(empty)
  );

  integer i;

  initial begin
    $dumpfile("fifo_tb.vcd");
    $dumpvars(0, fifo_tb);
    @(negedge rst); // Wait for reset deassertion

    // Write phase
    for (i = 0; i < DEPTH+2; i = i + 1) begin
      @(posedge clk);
      if (!full) begin
        write_en = 1;
        data_left_in  = $random;
        data_right_in = $random;
        $display("Write: left=0x%08X right=0x%08X", data_left_in, data_right_in);
      end else begin
        write_en = 0;
        $display("FIFO FULL at i=%0d", i);
      end
    end
    write_en = 0;

    // Read phase
    for (i = 0; i < DEPTH+2; i = i + 1) begin
      @(posedge clk);
      if (!empty) begin
        read_en = 1;
        $display("Read: left=0x%08X right=0x%08X", data_left_out, data_right_out);
      end else begin
        read_en = 0;
        $display("FIFO EMPTY at i=%0d", i);
      end
    end
    read_en = 0;

    #100;
    $finish;
  end

endmodule
