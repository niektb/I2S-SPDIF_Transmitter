`timescale 1ns/1ps

module spdif_core_tb();

    // Testbench signals
    reg clk_i;
    reg rst_i;
    reg bit_out_en_i;
    reg [31:0] sample_i;
    wire spdif_o;
    wire sample_req_o;

    // Instantiate the SPDIF core
    spdif_core uut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .bit_out_en_i(bit_out_en_i),
        .spdif_o(spdif_o),
        .sample_i(sample_i),
        .sample_req_o(sample_req_o)
    );

    // Instantiate the spdif_transmit module for comparison
    wire spdif_o2;

    spdif_transmit uut2 (
        .rst(rst_i),
        .clk(clk_i),
        .data_left(sample_i[15:0]),
        .data_right(sample_i[31:16]),
        .validity(1'b0),
        .sample_rate_code(4'b1100), // 48kHz
        .spdif_out(spdif_o2)
    );

    // add 3 cycles delay to spdif_o for alignment
    reg [2:0] spdif_o2_dly = 3'b000;
    always @(posedge clk_i) begin
        if (rst_i) begin
            spdif_o2_dly <= 3'b000;
        end else begin
            spdif_o2_dly <= {spdif_o2_dly[1:0], spdif_o2};
        end
    end

    // Clock generation: 24.576 MHz => period ~40.7 ns
    initial clk_i = 1;
    always #20 clk_i = ~clk_i;

    // Bit output enable generation
    initial begin
        bit_out_en_i = 0;
        forever begin
            #40; // half of bit period, adjust if needed
            bit_out_en_i = 1;
            #40;
            bit_out_en_i = 0;
        end
    end

    // Reset and initial sample
    initial begin
        rst_i = 1;
        sample_i = 32'h0000_0000;
        #100;
        rst_i = 0;
    end

    // Automatic sample feeding on sample_req_o
    reg [31:0] left_sample = 32'h0000_0000;
    reg [31:0] right_sample = 32'h0000_0000;

    always @(posedge clk_i) begin
        if (!rst_i && sample_req_o) begin
            // Simple ramp waveform for testing
            left_sample  <= left_sample + 32'h0000_1111;
            right_sample <= right_sample + 32'h0000_2222;
            sample_i <= {right_sample[15:0], left_sample[15:0]};
        end
    end

    // Monitor output
    initial begin
        $display("Time\tspdif_o\tsample_req");
        $monitor("%0t\t%b\t%b", $time, spdif_o, sample_req_o);
    end

    // Dump VCD for waveform viewing
    initial begin
        $dumpfile("spdif_core_tb.vcd");
        $dumpvars(0, spdif_core_tb);
    end

    // Stop simulation after some time
    initial begin
        #200000; // adjust simulation length
        $finish;
    end

endmodule
