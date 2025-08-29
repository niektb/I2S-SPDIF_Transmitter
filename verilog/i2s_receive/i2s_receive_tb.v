`timescale 1ns/1ns
module i2s_receive_tb;

    reg sck;
    always #40 sck = (sck === 1'b0);  

    reg clk;
    always #20 clk = (clk === 1'b0);  
  
    reg ws;
    always #2560 ws = (ws === 1'b0);

    reg reset = 1;
    initial begin
        repeat(10) @(posedge sck);
        reset <= 0;
    end

    //reg ws = 1;
    reg sd;
    wire [31:0] data_left, data_right;

    wire rx_en_tb;

    i2s_receive dut (
        .sck(sck),
        .clk(clk),
        .rst(reset),
        .rx_en(rx_en_tb),
        .ws(ws),
        .sd(sd),
        .data_left(data_left),
        .data_right(data_right)
    );

    rx_en_ws_check rx_en_inst (
        .clk(clk),
        .rst(reset),
        .ws(ws),
        .rx_en(rx_en_tb)
    );

  
    reg [31:0] expected_left, expected_right, sent_left, sent_right;
    reg [0:63] shift_data;

    common_test_util #(32) util(sck);

    reg stimulus_complete=0;
    event check_left_output;
    event check_right_output;

    initial begin
        // VCD dump for waveform
        $dumpfile("i2s_receive_tb.vcd");
        $dumpvars(0, i2s_receive_tb);

        wait (!reset);
        sd <= 0;
        @(negedge ws);

        // first 2 words will be ignored so send zeroes
        @(negedge sck);

        shift_data = {{32{1'b0}}, {32{1'b0}}};
        sent_left = shift_data[0:31];
        sent_right = shift_data[32:63];
    
        repeat (31) begin
            sd <= shift_data[0];
            shift_data <= shift_data<<1;
            @(negedge sck);
        end

        expected_left = sent_left;
        ->check_left_output;
        
        //ws <= 1;
        repeat (32) begin
        sd <= shift_data[0];
        shift_data <= shift_data<<1;
        @(negedge sck);
        end
        
        expected_right = sent_right;
        ->check_right_output;
        
        sd <= shift_data[0];


        repeat (100) begin
            @(negedge sck);

            shift_data = {{$random}, {$random}};
            sent_left = shift_data[0:31];
            sent_right = shift_data[32:63];
        
            repeat (31) begin
                sd <= shift_data[0];
                shift_data <= shift_data<<1;
                @(negedge sck);
            end

            expected_left = sent_left;
            ->check_left_output;
            
            //ws <= 1;
            repeat (32) begin
            sd <= shift_data[0];
            shift_data <= shift_data<<1;
            @(negedge sck);
            end
            
            expected_right = sent_right;
            ->check_right_output;
            
            sd <= shift_data[0];
            //ws <= 0;
        end
        
        stimulus_complete = 1;
    end

    always @(check_left_output) begin
        repeat (2) @(negedge sck);
        util.check(data_left,expected_left);
    end

    always @(check_right_output) begin
        repeat (2) @(negedge sck);
        util.check(data_right,expected_right);
    end
    
    initial begin
        util.init();

        wait (stimulus_complete);

        repeat (10) @(negedge sck);
        util.wrapup();
        $finish;
    end

endmodule

