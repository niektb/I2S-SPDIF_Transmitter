module fifo #(
    parameter WORDSIZE = 32,
    parameter DEPTH = 16
)
(
    input wire rst,
    input wire clk,
    input wire write_en,
    input wire read_en,
    input wire [WORDSIZE-1:0] data_left_in,
    input wire [WORDSIZE-1:0] data_right_in,
    output reg [WORDSIZE-1:0] data_left_out,
    output reg [WORDSIZE-1:0] data_right_out,
    output wire full,
    output wire empty
);

    localparam PTR_WIDTH = $clog2(DEPTH);

    reg [WORDSIZE-1:0] left_mem [0:DEPTH-1];
    reg [WORDSIZE-1:0] right_mem[0:DEPTH-1];
    reg [PTR_WIDTH-1:0] wr_ptr = 0; 
    reg [PTR_WIDTH-1:0] rd_ptr = 0;
    reg [$clog2(DEPTH+1)-1:0] count = 0;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
            data_left_out  <= 0;
            data_right_out <= 0;
        end else begin
            // Write
            if (write_en && !full) begin
                left_mem[wr_ptr]  <= data_left_in;
                right_mem[wr_ptr] <= data_right_in;
                wr_ptr <= wr_ptr + 1'b1;
            end
            // Read
            if (read_en && !empty) begin
                data_left_out  <= left_mem[rd_ptr];
                data_right_out <= right_mem[rd_ptr];
                rd_ptr <= rd_ptr + 1'b1;
            end
            // Count management
            case ({write_en && !full, read_en && !empty})
                2'b10: count <= count + 1; // Write only
                2'b01: count <= count - 1; // Read only
                default: count <= count;   // No change or simultaneous read/write
            endcase
        end
    end

endmodule
