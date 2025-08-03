`timescale 1us/1ns

module rgb_led_tb;
    reg clk = 0;
    reg rst = 0;
    wire red, green, blue;

    // Instantiate the RGB LED module
    rgb_led uut (
        .pin_clk_12mhz(clk),
        .red(red),
        .green(green),
        .blue(blue)
    );

    // Generate 12 MHz clock (period = 83.333 ns)    
    always begin
        #41.667ns 
        clk = ~clk;
    end

    initial begin
        #1
        rst = 1;
        #1
        rst = 0;
    end

    initial begin
        $dumpfile("rgb_led_tb.vcd");
        $dumpvars(0, rgb_led_tb);



        // Run long enough to see several color changes
        #(1000000);
        $display("Sim progress 25%");
        #(1000000);
        $display("Sim progress 50%");
        #(1000000);
        $display("Sim progress 75%");
        #(1000000);
        $display("Sim progress 100%");

        $finish;
    end
endmodule