module mat_vec_mult (
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire        start_compute,
    input  wire        clr_accum,
    
    // FIFO write interface for A matrix
    input  wire [7:0]  fifo_a_data_0,
    input  wire [7:0]  fifo_a_data_1,
    input  wire [7:0]  fifo_a_data_2,
    input  wire [7:0]  fifo_a_data_3,
    input  wire [7:0]  fifo_a_data_4,
    input  wire [7:0]  fifo_a_data_5,
    input  wire [7:0]  fifo_a_data_6,
    input  wire [7:0]  fifo_a_data_7,
    input  wire [7:0]  fifo_a_wren,
    output wire [7:0]  fifo_a_full,
    
    // FIFO write interface for B vector
    input  wire [7:0]  fifo_b_data,
    input  wire        fifo_b_wren,
    output wire        fifo_b_full,
    
    // Status
    output wire        all_fifos_full,
    output wire        compute_done,
    
    // MAC outputs
    output wire [23:0] mac_out_0,
    output wire [23:0] mac_out_1,
    output wire [23:0] mac_out_2,
    output wire [23:0] mac_out_3,
    output wire [23:0] mac_out_4,
    output wire [23:0] mac_out_5,
    output wire [23:0] mac_out_6,
    output wire [23:0] mac_out_7
);

    // FIFO outputs
    wire [7:0] fifo_a_out [0:7];
    wire [7:0] fifo_a_empty;
    wire [7:0] fifo_b_out;
    wire       fifo_b_empty;
    
    // FIFO read enables - staggered for systolic timing
    reg [7:0] fifo_a_rden;
    reg       fifo_b_rden;
    
    // MAC chain signals
    wire [7:0] mac_b_out_0, mac_b_out_1, mac_b_out_2, mac_b_out_3;
    wire [7:0] mac_b_out_4, mac_b_out_5, mac_b_out_6, mac_b_out_7;
    wire mac_en_out_0, mac_en_out_1, mac_en_out_2, mac_en_out_3;
    wire mac_en_out_4, mac_en_out_5, mac_en_out_6, mac_en_out_7;
    
    // First MAC enable (directly controlled)
    reg mac_en_first;
    
    // State machine
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] RUN     = 3'd1;
    localparam [2:0] DRAIN   = 3'd2;
    localparam [2:0] DONE_ST = 3'd3;
    
    reg [2:0] state;
    reg [4:0] cnt;
    
    assign all_fifos_full = (&fifo_a_full) && fifo_b_full;
    assign compute_done = (state == DONE_ST);
    
    // A FIFOs
    FIFO fifo_a0 (.clk(clk), .rst_n(rst_n), .rden(fifo_a_rden[0]), .wren(fifo_a_wren[0]),
                  .i_data(fifo_a_data_0), .o_data(fifo_a_out[0]), .full(fifo_a_full[0]), .empty(fifo_a_empty[0]));
    FIFO fifo_a1 (.clk(clk), .rst_n(rst_n), .rden(fifo_a_rden[1]), .wren(fifo_a_wren[1]),
                  .i_data(fifo_a_data_1), .o_data(fifo_a_out[1]), .full(fifo_a_full[1]), .empty(fifo_a_empty[1]));
    FIFO fifo_a2 (.clk(clk), .rst_n(rst_n), .rden(fifo_a_rden[2]), .wren(fifo_a_wren[2]),
                  .i_data(fifo_a_data_2), .o_data(fifo_a_out[2]), .full(fifo_a_full[2]), .empty(fifo_a_empty[2]));
    FIFO fifo_a3 (.clk(clk), .rst_n(rst_n), .rden(fifo_a_rden[3]), .wren(fifo_a_wren[3]),
                  .i_data(fifo_a_data_3), .o_data(fifo_a_out[3]), .full(fifo_a_full[3]), .empty(fifo_a_empty[3]));
    FIFO fifo_a4 (.clk(clk), .rst_n(rst_n), .rden(fifo_a_rden[4]), .wren(fifo_a_wren[4]),
                  .i_data(fifo_a_data_4), .o_data(fifo_a_out[4]), .full(fifo_a_full[4]), .empty(fifo_a_empty[4]));
    FIFO fifo_a5 (.clk(clk), .rst_n(rst_n), .rden(fifo_a_rden[5]), .wren(fifo_a_wren[5]),
                  .i_data(fifo_a_data_5), .o_data(fifo_a_out[5]), .full(fifo_a_full[5]), .empty(fifo_a_empty[5]));
    FIFO fifo_a6 (.clk(clk), .rst_n(rst_n), .rden(fifo_a_rden[6]), .wren(fifo_a_wren[6]),
                  .i_data(fifo_a_data_6), .o_data(fifo_a_out[6]), .full(fifo_a_full[6]), .empty(fifo_a_empty[6]));
    FIFO fifo_a7 (.clk(clk), .rst_n(rst_n), .rden(fifo_a_rden[7]), .wren(fifo_a_wren[7]),
                  .i_data(fifo_a_data_7), .o_data(fifo_a_out[7]), .full(fifo_a_full[7]), .empty(fifo_a_empty[7]));
    
    // B FIFO
    FIFO fifo_b (.clk(clk), .rst_n(rst_n), .rden(fifo_b_rden), .wren(fifo_b_wren),
                 .i_data(fifo_b_data), .o_data(fifo_b_out), .full(fifo_b_full), .empty(fifo_b_empty));
    
    // Chained MACs - B and En propagate through chain
    MAC mac0 (.clk(clk), .rst_n(rst_n), .En(mac_en_first), .Clr(clr_accum),
              .Ain(fifo_a_out[0]), .Bin(fifo_b_out), .Cout(mac_out_0),
              .En_out(mac_en_out_0), .Bout(mac_b_out_0));
    MAC mac1 (.clk(clk), .rst_n(rst_n), .En(mac_en_out_0), .Clr(clr_accum),
              .Ain(fifo_a_out[1]), .Bin(mac_b_out_0), .Cout(mac_out_1),
              .En_out(mac_en_out_1), .Bout(mac_b_out_1));
    MAC mac2 (.clk(clk), .rst_n(rst_n), .En(mac_en_out_1), .Clr(clr_accum),
              .Ain(fifo_a_out[2]), .Bin(mac_b_out_1), .Cout(mac_out_2),
              .En_out(mac_en_out_2), .Bout(mac_b_out_2));
    MAC mac3 (.clk(clk), .rst_n(rst_n), .En(mac_en_out_2), .Clr(clr_accum),
              .Ain(fifo_a_out[3]), .Bin(mac_b_out_2), .Cout(mac_out_3),
              .En_out(mac_en_out_3), .Bout(mac_b_out_3));
    MAC mac4 (.clk(clk), .rst_n(rst_n), .En(mac_en_out_3), .Clr(clr_accum),
              .Ain(fifo_a_out[4]), .Bin(mac_b_out_3), .Cout(mac_out_4),
              .En_out(mac_en_out_4), .Bout(mac_b_out_4));
    MAC mac5 (.clk(clk), .rst_n(rst_n), .En(mac_en_out_4), .Clr(clr_accum),
              .Ain(fifo_a_out[5]), .Bin(mac_b_out_4), .Cout(mac_out_5),
              .En_out(mac_en_out_5), .Bout(mac_b_out_5));
    MAC mac6 (.clk(clk), .rst_n(rst_n), .En(mac_en_out_5), .Clr(clr_accum),
              .Ain(fifo_a_out[6]), .Bin(mac_b_out_5), .Cout(mac_out_6),
              .En_out(mac_en_out_6), .Bout(mac_b_out_6));
    MAC mac7 (.clk(clk), .rst_n(rst_n), .En(mac_en_out_6), .Clr(clr_accum),
              .Ain(fifo_a_out[7]), .Bin(mac_b_out_6), .Cout(mac_out_7),
              .En_out(mac_en_out_7), .Bout(mac_b_out_7));
        
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cnt <= 5'd0;
            fifo_a_rden <= 8'd0;
            fifo_b_rden <= 1'b0;
            mac_en_first <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    fifo_a_rden <= 8'd0;
                    fifo_b_rden <= 1'b0;
                    mac_en_first <= 1'b0;
                    cnt <= 5'd0;
                    
                    if (start_compute && all_fifos_full) begin
                        // Start B and A[0] reads
                        fifo_b_rden <= 1'b1;
                        fifo_a_rden[0] <= 1'b1;
                        state <= RUN;
                    end
                end
                
                RUN: begin
                    cnt <= cnt + 1;
                    
                    // Enable first MAC at cnt=0 (data valid immediately)
                    if (cnt <= 5'd7) begin
                        mac_en_first <= 1'b1;
                    end else begin
                        mac_en_first <= 1'b0;
                    end
                    
                    // Staggered A FIFO read starts (A[i] starts i cycles after A[0])
                    // A[0] started in IDLE, so A[1] starts at cnt=0, A[2] at cnt=1, etc.
                    case (cnt)
                        5'd0: fifo_a_rden[1] <= 1'b1;
                        5'd1: fifo_a_rden[2] <= 1'b1;
                        5'd2: fifo_a_rden[3] <= 1'b1;
                        5'd3: fifo_a_rden[4] <= 1'b1;
                        5'd4: fifo_a_rden[5] <= 1'b1;
                        5'd5: fifo_a_rden[6] <= 1'b1;
                        5'd6: fifo_a_rden[7] <= 1'b1;
                    endcase
                    
                    // B FIFO: read 8 values (cnt 0-7), stop at cnt 7
                    if (cnt == 5'd7) fifo_b_rden <= 1'b0;
                    
                    // A FIFOs: each reads 8 values then stops
                    // A[0] started in IDLE, reads during cnt 0-6, stop at cnt 7
                    // A[1] starts at cnt 0, reads during cnt 0-7, stop at cnt 8
                    // A[i] starts at cnt i-1, reads 8 values, stops at cnt i+6
                    case (cnt)
                        5'd7:  fifo_a_rden[0] <= 1'b0;
                        5'd8:  fifo_a_rden[1] <= 1'b0;
                        5'd9:  fifo_a_rden[2] <= 1'b0;
                        5'd10: fifo_a_rden[3] <= 1'b0;
                        5'd11: fifo_a_rden[4] <= 1'b0;
                        5'd12: fifo_a_rden[5] <= 1'b0;
                        5'd13: fifo_a_rden[6] <= 1'b0;
                        5'd14: begin
                            fifo_a_rden[7] <= 1'b0;
                            state <= DRAIN;
                            cnt <= 5'd0;
                        end
                    endcase
                end
                
                DRAIN: begin
                    // Wait for En to propagate through MAC chain (7 cycles)
                    // Plus 1 extra cycle for pipeline flush in each MAC
                    cnt <= cnt + 1;
                    mac_en_first <= 1'b0;
                    
                    if (cnt == 5'd8) begin  // Was 7, now 8 for pipeline
                        state <= DONE_ST;
                    end
                end
                
                DONE_ST: begin
                    fifo_a_rden <= 8'd0;
                    fifo_b_rden <= 1'b0;
                    mac_en_first <= 1'b0;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule