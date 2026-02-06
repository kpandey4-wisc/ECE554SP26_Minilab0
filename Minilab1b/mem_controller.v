module mem_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    
    // Avalon MM Master Interface  
    output reg  [31:0] avm_address,
    output reg         avm_read,
    input  wire [63:0] avm_readdata,
    input  wire        avm_readdatavalid,
    input  wire        avm_waitrequest,
    
    // FIFO write interface for A matrix
    output reg  [7:0]  fifo_a_data_0,
    output reg  [7:0]  fifo_a_data_1,
    output reg  [7:0]  fifo_a_data_2,
    output reg  [7:0]  fifo_a_data_3,
    output reg  [7:0]  fifo_a_data_4,
    output reg  [7:0]  fifo_a_data_5,
    output reg  [7:0]  fifo_a_data_6,
    output reg  [7:0]  fifo_a_data_7,
    output reg  [7:0]  fifo_a_wren,
    input  wire [7:0]  fifo_a_full,
    
    // FIFO write interface for B vector
    output reg  [7:0]  fifo_b_data,
    output reg         fifo_b_wren,
    input  wire        fifo_b_full,
    
    // Status
    output reg         done,
    output wire [2:0]  state_out
);

    // States
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SEND_REQ  = 3'd1;
    localparam [2:0] WAIT_RESP = 3'd2;
    localparam [2:0] WRITE_A   = 3'd3;
    localparam [2:0] WRITE_B   = 3'd4;
    localparam [2:0] DONE_ST   = 3'd5;
    
    reg [2:0] state;
    reg [3:0] addr_cnt;     // Address counter (0-8)
    reg [2:0] byte_cnt;     // Byte counter within row (0-7)
    reg [63:0] captured_data;
    
    assign state_out = state;
    
    // Byte extraction from 64-bit word
    // Memory stores: addr[0] = 0x0102030405060708 where 01 is byte 0
    // So byte[i] = word[63-i*8 -: 8] = word[(7-i)*8 +: 8]
    wire [7:0] current_byte;
    assign current_byte = captured_data[(7-byte_cnt)*8 +: 8];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            avm_address <= 32'd0;
            avm_read <= 1'b0;
            addr_cnt <= 4'd0;
            byte_cnt <= 3'd0;
            captured_data <= 64'd0;
            done <= 1'b0;
            fifo_a_wren <= 8'd0;
            fifo_b_wren <= 1'b0;
            fifo_a_data_0 <= 8'd0;
            fifo_a_data_1 <= 8'd0;
            fifo_a_data_2 <= 8'd0;
            fifo_a_data_3 <= 8'd0;
            fifo_a_data_4 <= 8'd0;
            fifo_a_data_5 <= 8'd0;
            fifo_a_data_6 <= 8'd0;
            fifo_a_data_7 <= 8'd0;
            fifo_b_data <= 8'd0;
        end else begin
            // Defaults
            fifo_a_wren <= 8'd0;
            fifo_b_wren <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    avm_read <= 1'b0;
                    addr_cnt <= 4'd0;
                    byte_cnt <= 3'd0;
                    if (start) begin
                        state <= SEND_REQ;
                    end
                end
                
                SEND_REQ: begin
                    // Send read request
                    avm_address <= {28'd0, addr_cnt};
                    avm_read <= 1'b1;
                    state <= WAIT_RESP;
                end
                
                WAIT_RESP: begin
                    // Keep read high until not waitrequest, then deassert
                    if (!avm_waitrequest) begin
                        avm_read <= 1'b0;
                    end
                    
                    // When data is valid, capture it
                    if (avm_readdatavalid) begin
                        captured_data <= avm_readdata;
                        byte_cnt <= 3'd0;
                        avm_read <= 1'b0;
                        
                        if (addr_cnt < 4'd8) begin
                            state <= WRITE_A;
                        end else begin
                            state <= WRITE_B;
                        end
                    end
                end
                
                WRITE_A: begin
                    // Write one byte to the appropriate A FIFO
                    case (addr_cnt)
                        4'd0: begin fifo_a_data_0 <= current_byte; fifo_a_wren <= 8'b00000001; end
                        4'd1: begin fifo_a_data_1 <= current_byte; fifo_a_wren <= 8'b00000010; end
                        4'd2: begin fifo_a_data_2 <= current_byte; fifo_a_wren <= 8'b00000100; end
                        4'd3: begin fifo_a_data_3 <= current_byte; fifo_a_wren <= 8'b00001000; end
                        4'd4: begin fifo_a_data_4 <= current_byte; fifo_a_wren <= 8'b00010000; end
                        4'd5: begin fifo_a_data_5 <= current_byte; fifo_a_wren <= 8'b00100000; end
                        4'd6: begin fifo_a_data_6 <= current_byte; fifo_a_wren <= 8'b01000000; end
                        4'd7: begin fifo_a_data_7 <= current_byte; fifo_a_wren <= 8'b10000000; end
                        default: ;
                    endcase
                    
                    if (byte_cnt == 3'd7) begin
                        // Done with this row
                        byte_cnt <= 3'd0;
                        addr_cnt <= addr_cnt + 1;
                        if (addr_cnt == 4'd7) begin
                            // Done with A, fetch B
                            state <= SEND_REQ;
                        end else begin
                            // More A rows
                            state <= SEND_REQ;
                        end
                    end else begin
                        byte_cnt <= byte_cnt + 1;
                    end
                end
                
                WRITE_B: begin
                    // Write one byte to B FIFO
                    fifo_b_data <= current_byte;
                    fifo_b_wren <= 1'b1;
                    
                    if (byte_cnt == 3'd7) begin
                        state <= DONE_ST;
                    end else begin
                        byte_cnt <= byte_cnt + 1;
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    avm_read <= 1'b0;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule