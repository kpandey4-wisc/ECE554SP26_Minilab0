module FIFO (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rden,
    input  wire        wren,
    input  wire [7:0]  i_data,
    output reg  [7:0]  o_data,
    output wire        full,
    output wire        empty
);

    // FIFO memory
    reg [7:0] fifo_mem [0:7];
    
    // Pointers (4 bits for wrap-around detection with depth 8)
    reg [3:0] read_ptr;
    reg [3:0] write_ptr;
    
    // Full and empty logic
    assign empty = (read_ptr == write_ptr);
    assign full = (read_ptr[2:0] == write_ptr[2:0]) && (read_ptr[3] != write_ptr[3]);
    
    // Write operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 4'd0;
        end else if (wren && !full) begin
            fifo_mem[write_ptr[2:0]] <= i_data;
            write_ptr <= write_ptr + 1;
        end
    end
    
    // Read operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= 4'd0;
            o_data <= 8'd0;
        end else if (rden && !empty) begin
            o_data <= fifo_mem[read_ptr[2:0]];
            read_ptr <= read_ptr + 1;
        end
    end

endmodule
